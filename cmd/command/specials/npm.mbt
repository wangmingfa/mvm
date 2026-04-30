///|
fn get_uninstall_cmds() -> Array[String] {
  ["uninstall", "un"]
}

///|
fn get_global_flags() -> Array[String] {
  ["--global", "-g"]
}

///|
pub async fn before_npm_command(
  npm_exe_path : String,
  args : ArrayView[String],
) -> Map[String, String]? {
  let global_uninstall = is_global_uninstall(args)
  if global_uninstall {
    let uninstall_cmds = get_uninstall_cmds()
    let global_flgas = get_global_flags()
    let pkgs = args.filter(arg => {
      !uninstall_cmds.any(cmd => arg == cmd) &&
      !global_flgas.any(flag => arg == flag)
    })
    // let node_dir = @fs_ext.join_path(npm_exe_path, "../../")
    let npm_pkg_home = @tool_def.mvm_npm_pkg_home()
    let result : Map[String, String] = {}
    walk_global_pkgs(npm_exe_path, pkgs, fn(cmd_name, _) {
      // key为命令的名称，value为对应npm-pkg中的软连接路径
      let symlink_file_path = @fs_ext.join_path(npm_pkg_home, cmd_name)
      result.set(cmd_name, symlink_file_path)
    })
    return Some(result)
  }
  None
}

///|
pub async fn after_npm_command(
  before_run_result : Map[String, String]?,
  npm_exe_path : String,
  args : ArrayView[String],
) -> Unit {
  let install_cmds = ["install", "i"]
  let uninstall_cmds = get_uninstall_cmds()

  let global_flgas = get_global_flags()
  // 判断是否为npm的全局安装，如果是，获取args中所有安装的包名
  let global_install = args.any(arg => install_cmds.any(cmd => arg == cmd)) &&
    args.any(arg => global_flgas.any(flag => arg == flag))
  // 判断是否为npm的全局卸载，如果是，获取args中所有卸载的包名
  let global_uninstall = is_global_uninstall(args)
  if global_install {
    let pkgs = args.filter(arg => {
      !install_cmds.any(cmd => arg == cmd) &&
      !global_flgas.any(flag => arg == flag)
    })
    // 全局安装
    handle_install_npm_global_package(npm_exe_path, pkgs)
  } else if global_uninstall {
    // 全局卸载
    let pkgs = args.filter(arg => {
      !uninstall_cmds.any(cmd => arg == cmd) &&
      !global_flgas.any(flag => arg == flag)
    })
    handle_uninstall_npm_global_package(before_run_result, npm_exe_path, pkgs)
  }
}

///|
fn is_global_uninstall(args : ArrayView[String]) -> Bool {
  let uninstall_cmds = get_uninstall_cmds()

  let global_flgas = get_global_flags()
  // 判断是否为npm的全局安装，如果是，获取args中所有安装的包名
  args.any(arg => uninstall_cmds.any(cmd => arg == cmd)) &&
  args.any(arg => global_flgas.any(flag => arg == flag))
}

///|
async fn walk_global_pkgs(
  npm_exe_path : String,
  pkgs : ArrayView[String],
  handle_pkg_cmd : async (String, String) -> Unit,
) -> Unit {
  let node_dir = @fs_ext.join_path(npm_exe_path, "../../")
  // 在mvm_bin目录下的npm-pkg目录添加所安装的npm包的所有全局命令的软连接
  for pkg in pkgs {
    let pkg_package_json_file_path = @fs_ext.join_path(
      node_dir,
      "lib/node_modules/\{pkg}/package.json",
    )
    if !@fs.exists(pkg_package_json_file_path) {
      continue
    }
    // 读取package.json中的bin字段的值
    let json = @fs.read_file(pkg_package_json_file_path).json()
    guard json is Object(map) else {
      @log.error(
        "NPM包 \{pkg} 的package.json格式有问题，文件路径：\{pkg_package_json_file_path}",
      )
      continue
    }
    guard map.get("bin") is Some(Object(bin)) else {
      @log.error(
        "NPM包 \{pkg} 的package.json中的bin格式有问题，文件路径：\{pkg_package_json_file_path}",
      )
      continue
    }
    let pkg_root_dir = @fs_ext.join_path(pkg_package_json_file_path, "../")
    for cmd_name, cmd_path in bin {
      @log.debug("NPM包的bin配置: \{cmd_name} \{cmd_path}")
      guard cmd_path is String(cmd_path) else {
        @log.error("NPM包的bin配置 \{cmd_name} 有问题")
        continue
      }
      let target_file_path = @fs_ext.join_path(pkg_root_dir, cmd_path)
      handle_pkg_cmd(cmd_name, target_file_path)
    }
  }
}

///|
async fn handle_install_npm_global_package(
  npm_exe_path : String,
  pkgs : ArrayView[String],
) -> Unit {
  // 全局安装
  @log.debug("NPM执行文件路径: \{npm_exe_path}")
  @log.debug("全局安装NPM包: \{pkgs}")

  let npm_pkg_home = @tool_def.mvm_npm_pkg_home()
  walk_global_pkgs(npm_exe_path, pkgs, async fn(cmd_name, cmd_path) {
    // 在mvm_bin/npm-pkg下建立软连接
    let symlink_file_path = @fs_ext.join_path(npm_pkg_home, cmd_name)
    // 如果文件存在，先删除
    if @fs.exists(symlink_file_path) {
      @fs.remove(symlink_file_path)
    }
    @fs.symlink(target=cmd_path, symlink_file_path)
    @log.debug("已在目录 \{npm_pkg_home} 安装全局命令 \{cmd_name}")
  })
}

///|
async fn handle_uninstall_npm_global_package(
  before_run_result : Map[String, String]?,
  npm_exe_path : String,
  pkgs : ArrayView[String],
) -> Unit {
  // 全局卸载
  @log.debug("NPM执行文件路径: \{npm_exe_path}")
  @log.debug("全局卸载NPM包: \{pkgs}")

  guard before_run_result is Some(before_run_result) else {
    @log.error("before_run_result不能为空")
    return
  }

  for _, sym_link_path in before_run_result {
    if @fs.exists(sym_link_path) {
      @log.debug("删除软连接 \{sym_link_path}")
      @fs.remove(sym_link_path)
    }
  }
}
