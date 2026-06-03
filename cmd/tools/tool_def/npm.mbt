///|
let uninstall_cmds : ReadOnlyArray[String] = ["uninstall", "un"]

///|
let global_flags : ReadOnlyArray[String] = ["--global", "-g"]

///|
struct Npm {}

///|
test "npm" {
  let _ = Npm::{  }
}

///|
pub async fn Npm::before_npm_command(
  npm_exe_path : String,
  args : ArrayView[String],
) -> Map[String, String]? {
  let global_uninstall = is_global_uninstall(args)
  if global_uninstall {
    let pkgs = args.filter(arg => {
      !uninstall_cmds.any(cmd => arg == cmd) &&
      !global_flags.any(flag => arg == flag)
    })
    let npm_pkg_home = mvm_npm_pkg_home()
    let result : Map[String, String] = {}
    walk_global_pkgs(npm_exe_path, pkgs, fn(cmd_name, _) {
      // key为命令的名称，value为对应npm-pkg中的软连接路径
      let symlink_file_path = @fs_ext.join_path(npm_pkg_home, cmd_name)
      @log.debug(
        "全局卸载，记录已卸载的全局命令: \{cmd_name} -> \{symlink_file_path}",
      )
      result.set(cmd_name, symlink_file_path)
    })
    return Some(result)
  }
  None
}

///|
pub async fn Npm::after_npm_command(
  before_run_result : Map[String, String]?,
  npm_exe_path : String,
  args : ArrayView[String],
) -> Unit {
  let install_cmds = ["install", "i"]
  let link_cmds = ["link", "ln"]
  let unlink_cmds = ["unlink"]

  // 判断是否为npm的全局安装，如果是，获取args中所有安装的包名
  let global_install = args.any(arg => install_cmds.any(cmd => arg == cmd)) &&
    args.any(arg => global_flags.any(flag => arg == flag))
  // 判断是否为npm的全局卸载，如果是，获取args中所有卸载的包名
  let global_uninstall = is_global_uninstall(args)
  // 判断是否为 npm link（无参数时链接当前项目到全局）
  let is_link = args.any(arg => link_cmds.any(cmd => arg == cmd))
  let link_args = args.filter(arg => !link_cmds.any(cmd => arg == cmd))
  // 判断是否为 npm unlink（无参数时从全局取消链接当前项目）
  let is_unlink = args.any(arg => unlink_cmds.any(cmd => arg == cmd))
  let unlink_args = args.filter(arg => !unlink_cmds.any(cmd => arg == cmd))

  if global_install {
    let pkgs = args.filter(arg => {
      !install_cmds.any(cmd => arg == cmd) &&
      !global_flags.any(flag => arg == flag)
    })
    // 全局安装
    handle_install_npm_global_package(npm_exe_path, pkgs)
  } else if global_uninstall {
    // 全局卸载：如果所有node版本中都没有该包了，删除npm-pkg中的shim文件
    guard before_run_result is Some(cmd_map) else { return }
    handle_uninstall_npm_global_package(cmd_map)
  } else if is_link && link_args.is_empty() {
    // npm link（无参数）：将当前项目链接到全局
    handle_npm_link()
  } else if is_unlink && unlink_args.is_empty() {
    // npm unlink（无参数）：从全局取消链接当前项目
    handle_npm_unlink()
  }
}

///|
fn is_global_uninstall(args : ArrayView[String]) -> Bool {
  // 判断是否为npm的全局安装，如果是，获取args中所有安装的包名
  args.any(arg => uninstall_cmds.any(cmd => arg == cmd)) &&
  args.any(arg => global_flags.any(flag => arg == flag))
}

///|
/// 遍历指定 package.json 中的 bin 字段，对每个命令调用 handle_pkg_cmd
async fn walk_pkg_bins(
  pkg_json_path : String,
  pkg_label : String,
  handle_pkg_cmd : async (String, String) -> Unit,
) -> Unit {
  if !@fs.exists(pkg_json_path) {
    return
  }
  // 读取package.json中的bin字段的值
  let json = @fs.read_file(pkg_json_path).json()
  guard json is Object(map) else {
    @log.warn(
      @i18n.t("npm.pkg_json_format_error", args={
        "pkg": pkg_label,
        "path": pkg_json_path,
      }),
    )
    return
  }
  guard map.get("bin") is Some(Object(bin)) else {
    @log.warn(
      @i18n.t("npm.pkg_bin_format_error", args={
        "pkg": pkg_label,
        "path": pkg_json_path,
      }),
    )
    return
  }
  let pkg_root_dir = @fs_ext.join_path(pkg_json_path, "../")
  for cmd_name, cmd_path in bin {
    @log.debug(
      @i18n.t("npm.bin_config_debug", args={
        "cmd_name": cmd_name,
        "bin_json": cmd_path.stringify(indent=2),
      }),
    )
    guard cmd_path is String(cmd_path) else {
      @log.warn(@i18n.t("npm.bin_config_error", args={ "cmd_name": cmd_name }))
      continue
    }
    let target_file_path = @fs_ext.join_path(pkg_root_dir, cmd_path)
    handle_pkg_cmd(cmd_name, target_file_path)
  }
}

///|
async fn walk_global_pkgs(
  npm_exe_path : String,
  pkgs : ArrayView[String],
  handle_pkg_cmd : async (String, String) -> Unit,
) -> Unit {
  let { lib: lib_dir, .. } = Node::get_node_path_by_node_inner_path(
    npm_exe_path,
  )
  // 在mvm_bin目录下的npm-pkg目录添加所安装的npm包的所有全局命令的软连接
  for pkg in pkgs {
    let pkg_json_path = @fs_ext.join_paths([
      lib_dir, "node_modules", pkg, "package.json",
    ])
    walk_pkg_bins(pkg_json_path, pkg, handle_pkg_cmd)
  }
}

///|
/// 收集所有已安装node版本中仍然可用的命令名
async fn collect_all_available_cmds() -> @set.Set[String] {
  let node_tool_dir = tool_dir(Node)
  let available_cmds : @set.Set[String] = @set.Set([])
  guard @fs.exists(node_tool_dir) else { return available_cmds }
  let os = @os.get_os_name()
  // 扫描所有已安装的node版本目录
  for name in @fs.readdir(node_tool_dir) {
    let version_path = @fs_ext.join_path(node_tool_dir, name)
    guard @fs.kind(version_path) is Directory else { continue }
    // 计算lib目录：windows下和node_dir相同，linux/mac下为node_dir/lib
    let node_dir = version_dir(Node, name)
    let lib_dir = if os is Windows {
      node_dir
    } else {
      @fs_ext.join_path(node_dir, "lib")
    }
    let lib_node_modules_dir = @fs_ext.join_path(lib_dir, "node_modules")
    guard @fs.exists(lib_node_modules_dir) else { continue }
    // 扫描node_modules下的所有包，收集bin命令名
    for lib_name in @fs.readdir(lib_node_modules_dir) {
      let lib_path = @fs_ext.join_path(lib_node_modules_dir, lib_name)
      // 处理scoped包（如@google/gemini-cli）
      // @google目录下可能有多个子包，需要逐一检查
      if lib_name.has_prefix("@") {
        guard @fs.kind(lib_path) is Directory else { continue }
        guard @fs.exists(lib_path) else { continue }
        for sub_name in @fs.readdir(lib_path) {
          let sub_path = @fs_ext.join_path(lib_path, sub_name)
          let pkg_json_path = @fs_ext.join_path(sub_path, "package.json")
          walk_pkg_bins(pkg_json_path, lib_name + "/" + sub_name, fn(
            cmd_name,
            _cmd_path,
          ) {
            available_cmds.add(cmd_name)
          })
        }
      } else {
        let pkg_json_path = @fs_ext.join_path(lib_path, "package.json")
        walk_pkg_bins(pkg_json_path, lib_name, fn(cmd_name, _cmd_path) {
          available_cmds.add(cmd_name)
        })
      }
    }
  }
  available_cmds
}

///|
/// 处理npm全局卸载：如果所有node版本中都没有该包了，删除npm-pkg中的shim文件
async fn handle_uninstall_npm_global_package(
  before_run_result : Map[String, String],
) -> Unit {
  let available_cmds = collect_all_available_cmds()
  let npm_pkg_home = mvm_npm_pkg_home()
  let os = @os.get_os_name()
  let exts = match os {
    Windows => ["", ".ps1", ".cmd"]
    _ => [""]
  }
  for cmd_name, _ in before_run_result {
    if !available_cmds.contains(cmd_name) {
      // 删除 mvm_bin/npm-pkg 下的 shim 脚本
      for ext in exts {
        let shim_path = @fs_ext.join_path(npm_pkg_home, cmd_name + ext)
        @fs_ext.remove_if_exists(shim_path)
      }
      @log.debug(
        @i18n.t("npm.unlink_cmd_removed", args={
          "dir": npm_pkg_home,
          "cmd": cmd_name,
        }),
      )
    }
  }
}

///|
async fn handle_install_npm_global_package(
  npm_exe_path : String,
  pkgs : ArrayView[String],
) -> Unit {
  // 全局安装
  // NPM执行文件路径
  @log.debug(@i18n.t("npm.exe_path_debug", args={ "path": npm_exe_path }))
  // 全局安装NPM包
  @log.debug(
    @i18n.t("npm.global_install_debug", args={
      "pkgs": to_repr(pkgs).to_string(),
    }),
  )

  let npm_pkg_home = mvm_npm_pkg_home()
  let os = @os.get_os_name()
  walk_global_pkgs(npm_exe_path, pkgs, async fn(cmd_name, _cmd_path) {
    // 在mvm_bin/npm-pkg下建立软连接
    // let symlink_file_path = @fs_ext.join_path(npm_pkg_home, cmd_name)
    // // 如果文件存在，先删除
    // if @fs.exists(symlink_file_path) {
    //   @fs.remove(symlink_file_path)
    // }
    // @fs.symlink(target=cmd_path, symlink_file_path)
    match os {
      MacOS | Linux => create_tool_cmd_unix(Node, cmd_name, cmd_dir=NPM_PKG)
      Windows => create_tool_cmd_windows(Node, cmd_name, cmd_dir=NPM_PKG)
      _ => ()
    }
    // 已安装全局命令
    @log.debug(
      @i18n.t("npm.global_cmd_installed", args={
        "dir": npm_pkg_home,
        "cmd": cmd_name,
      }),
    )
  })
}

///|
/// 处理 npm link（无参数）：将当前项目链接到全局，并创建 bin 命令
async fn handle_npm_link() -> Unit {
  guard @env.current_dir() is Some(cwd) else {
    @log.warn(@i18n.t("npm.link_no_cwd"))
    return
  }
  let pkg_json_path = @fs_ext.join_path(cwd, "package.json")
  if !@fs.exists(pkg_json_path) {
    @log.warn(@i18n.t("npm.link_no_package_json", args={ "dir": cwd }))
    return
  }
  @log.debug(@i18n.t("npm.link_debug", args={ "dir": cwd }))
  let npm_pkg_home = mvm_npm_pkg_home()
  let os = @os.get_os_name()
  walk_pkg_bins(pkg_json_path, cwd, async fn(cmd_name, _cmd_path) {
    // 在 mvm_bin/npm-pkg 下创建 shim 脚本
    match os {
      MacOS | Linux => create_tool_cmd_unix(Node, cmd_name, cmd_dir=NPM_PKG)
      Windows => create_tool_cmd_windows(Node, cmd_name, cmd_dir=NPM_PKG)
      _ => ()
    }
    @log.debug(
      @i18n.t("npm.link_cmd_created", args={
        "dir": npm_pkg_home,
        "cmd": cmd_name,
      }),
    )
  })
}

///|
/// 处理 npm unlink（无参数）：从全局取消链接当前项目，并删除 bin 命令
async fn handle_npm_unlink() -> Unit {
  guard @env.current_dir() is Some(cwd) else {
    @log.warn(@i18n.t("npm.unlink_no_cwd"))
    return
  }
  let pkg_json_path = @fs_ext.join_path(cwd, "package.json")
  if !@fs.exists(pkg_json_path) {
    @log.warn(@i18n.t("npm.unlink_no_package_json", args={ "dir": cwd }))
    return
  }
  @log.debug(@i18n.t("npm.unlink_debug", args={ "dir": cwd }))
  let npm_pkg_home = mvm_npm_pkg_home()
  let os = @os.get_os_name()
  walk_pkg_bins(pkg_json_path, cwd, async fn(cmd_name, _cmd_path) {
    // 删除 mvm_bin/npm-pkg 下的 shim 脚本
    let exts = match os {
      Windows => ["", ".ps1", ".cmd"]
      _ => [""]
    }
    for ext in exts {
      let shim_path = @fs_ext.join_paths([npm_pkg_home, cmd_name + ext])
      @fs_ext.remove_if_exists(shim_path)
    }
    @log.debug(
      @i18n.t("npm.unlink_cmd_removed", args={
        "dir": npm_pkg_home,
        "cmd": cmd_name,
      }),
    )
  })
}
