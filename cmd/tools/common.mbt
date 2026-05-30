///|
using @tool_def {
  type Node,
  type Bun,
  type Zig,
  type Go,
  type Python,
  type Rust,
  type Deno,
  type Java,
  type Kotlin,
}

///|
pub using @tool_def {
  type Tool,
  type ProgramExeInfo,
  type DownloadInfo,
  type NodePath,
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
  get_managed_tools,
  validate_managed_tools_value,
  create_tool_cmd_unix,
  create_tool_cmd_windows,
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
pub async fn get_target_version(tool : Tool, version : String) -> String {
  let os_info = @os.get_os_info()
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
pub fn get_download_info(tool : Tool, version : String) -> DownloadInfo raise {
  let os_info = @os.get_os_info()
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
  }
}

///|
/// 获取某个工具下的命令的可执行文件路径和版本信息
/// 比如 mvm run node@18 -- node -v 中，tool就是node，program也是node
/// 比如 mvm run node@18 -- npm -v 中，tool就是node，program就是npm
pub async fn get_program_exe_info(
  tool : Tool,
  program : String,
  version : String,
) -> ProgramExeInfo {
  let effective_version = if version.is_blank() {
    guard get_config(tool~) is Some((_, config)) &&
      config.get_value(tool) is Some(v) else {
      // 找不到合适的版本
      let msg = [
        "未指定",
        @utils.yellow(program),
        "的版本，请使用",
        @utils.yellow("mvm use \{program}@version"),
        "指定版本，或使用",
        @utils.yellow("mvm use \{program}"),
        "指定为最新版",
      ].join(" ")
      raise fail(msg)
    }
    v
  } else {
    version
  }
  // 通过get_target_version转换一次，因为有可能用户没有提供完整的版本号
  let effective_version = get_target_version(tool, effective_version)
  match tool {
    Node => Node::get_program_exe_info(program, effective_version)
    Bun => Bun::get_program_exe_info(program, effective_version)
    Zig => Zig::get_program_exe_info(program, effective_version)
    Go => Go::get_program_exe_info(program, effective_version)
    Python => Python::get_program_exe_info(program, effective_version)
    Rust => Rust::get_program_exe_info(program, effective_version)
    Deno => Deno::get_program_exe_info(program, effective_version)
    Java => Java::get_program_exe_info(program, effective_version)
    Kotlin => Kotlin::get_program_exe_info(program, effective_version)
  }
}

///|
pub async fn post_install(tool : Tool, target_dir : String) -> Unit {
  let os = @os.get_os_name()
  if os is Linux || os is MacOS {
    // 增加可执行权限
    // macOS JDK 使用 .app bundle 结构，实际路径为 Contents/Home/bin/
    let java_bin_dir = if os is MacOS { "Contents/Home/bin" } else { "bin" }
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
          @fs_ext.join_path(target_dir, "\{java_bin_dir}/\{name}")
        })
      // Kotlin 编译器的可执行文件在 bin 子目录下
      Kotlin =>
        ["kotlinc", "kotlin"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
    }
    // exe_files.insert(0, "+x")
    let msg = exe_files.join(",")
    @log.debug("增加可执行权限: \{msg}")
    // let _ = @process.run("chmod", exe_files)
    @mvm_cmd.chmod_x(exe_files)
  }
}

///|
pub fn tool_version_str(tool : Tool, version? : String) -> String {
  [tool.to_string(), if version is Some(v) { v } else { "" }]
  .filter(v => !v.is_blank())
  .join("@")
}

///|
/// 准备运行命令的参数
/// 根据工具类型对 program_exe_info 和 exec_args 进行预处理
/// 返回最终要执行的可执行文件路径和参数列表
/// 例如：Node 工具中，如果程序是 .js 文件，需要用 node 来执行
pub fn prepare_run_command(
  program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> (String, Array[String]) {
  let { tool, path, extra_args, .. } = program_exe_info
  match tool {
    Node => Node::prepare_run_command(program_exe_info, exec_args)
    // 其他工具目前直接使用原始路径和参数
    Bun | Zig | Go | Python | Rust | Deno | Java | Kotlin =>
      (path, [..extra_args, ..exec_args])
  }
}

///|
pub async fn before_command(
  get_program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Map[String, String]? {
  let { tool, .. } = get_program_exe_info
  match tool {
    Node => Node::before_command(get_program_exe_info, exec_args)
    _ => None
  }
}

///|
pub async fn after_command(
  before_run_result : Map[String, String]?,
  get_program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Unit {
  let { tool, .. } = get_program_exe_info
  match tool {
    Node =>
      Node::after_command(before_run_result, get_program_exe_info, exec_args)
    _ => ()
  }
}
