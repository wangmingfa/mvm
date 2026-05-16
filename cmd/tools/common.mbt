///|
using @tool_def {
  type Node,
  type Bun,
  type Zig,
  type Go,
  type ToolExe,
  type Python,
  type Rust,
  type Deno,
  type Java,
  type Kotlin,
}

///|
pub using @tool_def {
  type Tool,
  type DownloadInfo,
  set_no_cache_mode,
  is_no_cache_mode,
  write_global_config,
  remove_global_config,
  write_project_config,
  mvm_home,
  is_installed,
  tool_dir,
  version_dir,
  get_config,
  cache_dir,
  temp_dir,
  get_global_config,
  save_global_config,
  replace_url,
  apply_global_config,
  make_global_config,
  type UrlReplaceContext,
  type GlobalConfig,
  NPM_PKG,
}

///|
using @os {type OsInfo}

///|
fn parse_version(version : String) -> (String, Int) {
  // version支持这些格式：
  // lts：下载lts版本
  // latest：下载最新版本
  // 20：指定主版本，下载20版本下的最新版本
  // 20.1：指定主版本和次版本，下载20.1版本下的最新版本
  // 24.1.0：指定完整的版本

  let version_count = lexmatch version with longest {
    // x.y.z
    "v?[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" => 3
    // x.y
    "v?[[:digit:]]+\.[[:digit:]]+" => 2
    // x
    "v?[[:digit:]]+" => 1
    _ => 0
  }
  return (version, version_count)
}

///|
pub async fn get_target_version(
  os_info : OsInfo,
  tool : Tool,
  version : String,
) -> String {
  let (version, version_count) = parse_version(version)
  match tool {
    Node => Node::get_target_version(os_info, version, version_count)
    Bun => Bun::get_target_version(os_info, version, version_count)
    Zig => Zig::get_target_version(os_info, version, version_count)
    Go => Go::get_target_version(os_info, version, version_count)
    Python => Python::get_target_version(os_info, version, version_count)
    Rust => Rust::get_target_version(os_info, version, version_count)
    Deno => Deno::get_target_version(os_info, version, version_count)
    Java => Java::get_target_version(os_info, version, version_count)
    Kotlin => Kotlin::get_target_version(os_info, version, version_count)
    _ => raise fail("不支持的工具：\{tool}")
  }
}

///|
/// 获取指定工具版本的期望 SHA256 checksum
/// 返回 None 表示该工具暂不支持 checksum 校验
pub async fn get_expected_checksum(
  os_info : OsInfo,
  tool : Tool,
  version : String,
) -> String? {
  match tool {
    Node => Node::get_expected_checksum(os_info, version)
    Zig => Zig::get_expected_checksum(os_info, version)
    Go => Go::get_expected_checksum(os_info, version)
    Bun => Bun::get_expected_checksum(os_info, version)
    Python => Python::get_expected_checksum(os_info, version)
    Rust => Rust::get_expected_checksum(os_info, version)
    Java => Java::get_expected_checksum(os_info, version)
    // Deno 和 Kotlin 无官方校验文件
    Deno | Kotlin => None
    _ => None
  }
}

///|
pub fn match_version(
  tool : Tool,
  version : String,
  target_version : String,
) -> Bool {
  @log.debug(
    "tool: \{tool}, version: \{version}, target_version: \{target_version}",
  )
  match tool {
    // Python、Rust、Deno 版本号带 "v" 前缀（与 Node/Bun/Zig 一致）
    Node | Zig | Bun | Python | Rust | Deno => {
      let handle_version = if version.has_prefix("v") {
        version
      } else {
        "v\{version}"
      }
      if handle_version == target_version {
        return true
      }
      if target_version.has_prefix(handle_version) {
        let len = handle_version.length()
        let next_s = target_version[len:len + 1]
        let _ = @string.parse_int(next_s) catch { _ => return true }
        // 如果下一位是数字，则匹配不通过
        return false
      }
      false
    }
    // Java、Kotlin 版本号不带 "v" 前缀（与 Go 一致）
    Go | Java | Kotlin => {
      // 版本号不带 "v" 前缀（如 "1.23.4"、"21.0.2"）
      let handle_version = if version.has_prefix("v") {
        version[1:]
      } else {
        version
      }
      if handle_version == target_version {
        return true
      }
      if target_version.has_prefix(handle_version) {
        let len = handle_version.length()
        let next_s = target_version[len:len + 1]
        let _ = @string.parse_int(next_s) catch { _ => return true }
        return false
      }
      false
    }
    _ => false
  }
}

///|
test "match_version" {
  inspect(
    match_version(Node, "18", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "v18", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "1", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Node, "v1", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Node, "18.20", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "v18.20", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "18.2", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Bun, "1.3.12", "v1.3.12"),
    content=(
      #|true
    ),
  )
}

///|
/// 获取下载信息（URL、headers 和压缩包目录深度）
/// DownloadInfo 包含：
///   url: 下载地址
///   headers: 下载请求需要携带的 headers
///   root_path_depth: 压缩包解压出来之后，需要进入多少层级才能到达实际工具根目录
pub fn get_download_info(
  os_info : OsInfo,
  tool : Tool,
  version : String,
) -> DownloadInfo raise {
  match tool {
    Node => Node::get_download_info(os_info, version)
    Bun => Bun::get_download_info(os_info, version)
    Zig => Zig::get_download_info(os_info, version)
    Go => Go::get_download_info(os_info, version)
    Python => Python::get_download_info(os_info, version)
    Rust => Rust::get_download_info(os_info, version)
    Deno => Deno::get_download_info(os_info, version)
    Java => Java::get_download_info(os_info, version)
    Kotlin => Kotlin::get_download_info(os_info, version)
    _ => raise fail("无法获取 \{tool} 的下载信息")
  }
}

///|
/// 获取工具的运行路径，返回路径、版本和运行此命令需要的环境变量
async fn _get_tool_exe_path(tool : Tool) -> ToolExe? {
  guard get_config(tool~) is Some((_, config)) &&
    config.get_value(tool) is Some(version) else {
    return None
  }
  let path = get_exe_path_for_version(tool, version)
  Some(ToolExe::new(tool, path, version))
}

///|
/// 根据指定的版本获取工具可执行文件路径（不依赖配置文件，直接使用传入的版本）
pub fn get_exe_path_for_version(tool : Tool, version : String) -> String raise {
  let path = match tool {
    Node => Node::get_exe_path(version)
    Bun => Bun::get_exe_path(version)
    Zig => Zig::get_exe_path(version)
    Go => Go::get_exe_path(version)
    Python => Python::get_exe_path(version)
    Rust => Rust::get_exe_path(version)
    Deno => Deno::get_exe_path(version)
    Java => Java::get_exe_path(version)
    Kotlin => Kotlin::get_exe_path(version)
    // 内置工具跟随主工具的路径结构
    Cargo => Rust::get_exe_path(version)
    Javac | Jar => Java::get_exe_path(version)
    Kotlinc => Kotlin::get_exe_path(version)
    _ => raise fail("不支持的工具：\{tool}")
  }
  @fs_ext.canonicalize_path(path)
}

///|
pub async fn get_tool_exe_path(tool : Tool) -> ToolExe? {
  let is_node_builtin_tools = @tool_def.Tool::is_node_builtin_tools(tool)
  let is_rust_builtin_tools = @tool_def.Tool::is_rust_builtin_tools(tool)
  let is_java_builtin_tools = @tool_def.Tool::is_java_builtin_tools(tool)
  let is_kotlin_builtin_tools = @tool_def.Tool::is_kotlin_builtin_tools(tool)

  // 内置工具需要查找所属的主工具版本
  let real_tool = @tool_def.Tool::get_belonging_tools(tool)
  let res = _get_tool_exe_path(real_tool)

  if is_node_builtin_tools {
    guard res is Some(node_tool_exe) else { return None }
    return @tool_def.Node::get_node_builtin_tool_path_and_version(
      tool, node_tool_exe,
    )
  }
  if is_rust_builtin_tools {
    guard res is Some(rust_tool_exe) else { return None }
    return @tool_def.Rust::get_rust_builtin_tool_path_and_version(
      tool, rust_tool_exe,
    )
  }
  if is_java_builtin_tools {
    guard res is Some(java_tool_exe) else { return None }
    return @tool_def.Java::get_java_builtin_tool_path_and_version(
      tool, java_tool_exe,
    )
  }
  if is_kotlin_builtin_tools {
    guard res is Some(kotlin_tool_exe) else { return None }
    return @tool_def.Kotlin::get_kotlin_builtin_tool_path_and_version(
      tool, kotlin_tool_exe,
    )
  }
  res
}

///|
pub async fn post_install(tool : Tool, target_dir : String) -> Unit {
  let os = @os.get_os_name()
  if os is Linux || os is MacOS {
    // 增加可执行权限
    let exe_files = match tool {
      Node =>
        ["node", "npm", "npx"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
      Zig => [@fs_ext.join_path(target_dir, "zig")]
      Bun => [@fs_ext.join_path(target_dir, "bun")]
      Go =>
        ["go", "gofmt"].map(name => @fs_ext.join_path(target_dir, "bin/\{name}"))
      // Python 可执行文件在 bin 子目录下
      Python => [@fs_ext.join_path(target_dir, "bin/python3")]
      // Rust 的可执行文件在 bin 子目录下
      Rust =>
        ["rustc", "cargo"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
      // Deno 是单一二进制文件，无 bin 子目录
      Deno => [@fs_ext.join_path(target_dir, "deno")]
      // Java (JDK) 的可执行文件在 bin 子目录下
      Java =>
        ["java", "javac", "jar"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
      // Kotlin 编译器的可执行文件在 bin 子目录下
      Kotlin =>
        ["kotlinc", "kotlin"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
      _ => []
    }
    // exe_files.insert(0, "+x")
    let msg = exe_files.join(",")
    @log.debug("增加可执行权限: \{msg}")
    // let _ = @process.run("chmod", exe_files)
    @mvm_cmd.chmod_x(exe_files)
  }
}

///|
pub async fn create_tool_cmd_unix(
  tool : Tool,
  cmd_name : String,
  file_name? : String = cmd_name,
  cmd_dir? : String = "",
) -> Unit {
  // 创建一个shell文件（不需要.sh后缀），里面执行mvm run {tool} -- {cmd_name} "$@"
  let mvm_bin = @tool_def.mvm_bin_home()
  let shell_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, file_name])
  let tool_name = tool.to_string()
  let shell_content = "#!/bin/sh\nmvm run \{tool_name} -- \{cmd_name} \"$@\""
  @fs.write_file(shell_file_path, shell_content, create_mode=CreateOrTruncate)
  // 添加可执行权限
  @mvm_cmd.chmod_x([shell_file_path])
  @log.debug("创建shell文件 \{shell_file_path}")
}

///|
pub async fn create_tool_cmd_windows(
  tool : Tool,
  cmd_name : String,
  file_name? : String = cmd_name,
  cmd_dir? : String = "",
) -> Unit {
  // 创建ps1、cmd文件，里面执行mvm run {tool} -- {cmd_name} $args / %*
  let mvm_bin = @tool_def.mvm_bin_home()
  let ps1_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, "\{file_name}.ps1"])
  let cmd_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, "\{file_name}.cmd"])
  let tool_name = tool.to_string()
  let ps1_content = "mvm run \{tool_name} -- \{cmd_name} $args"
  let cmd_content = "@mvm run \{tool_name} -- \{cmd_name} %*"
  @fs.write_file(ps1_file_path, ps1_content, create_mode=CreateOrTruncate)
  @fs.write_file(cmd_file_path, cmd_content, create_mode=CreateOrTruncate)
  @log.debug("创建ps1文件 \{ps1_file_path}")
  @log.debug("创建cmd文件 \{cmd_file_path}")
}
