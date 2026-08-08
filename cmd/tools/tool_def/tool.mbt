// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
/// MVM 主目录
pub fn mvm_home() -> String raise {
  if @env.get_env_var("MVM_HOME") is Some(home) {
    return home
  }
  let os = @os.get_os_name()
  let home = if os is Windows {
    @env.get_env_var("USERPROFILE")
  } else {
    @env.get_env_var("HOME")
  }
  guard home is Some(home) else { raise fail(@i18n.t("error.no_home_dir")) }
  @fs_ext.join_path(home, ".mvm")
}

///|
pub fn mvm_bin_home() -> String raise {
  @fs_ext.join_path(mvm_home(), "bin")
}

///|
pub const NPM_PKG = "npm-pkg"

///|
pub fn mvm_npm_pkg_home() -> String raise {
  @fs_ext.join_path(mvm_bin_home(), NPM_PKG)
}

///|
/// 工具安装目录
fn tools_dir() -> String raise {
  @fs_ext.join_path(mvm_home(), "tools")
}

///|
/// 获取特定工具的安装目录
pub fn tool_dir(tool : Tool) -> String raise {
  @fs_ext.join_path(tools_dir(), tool.to_string().to_lower())
}

///|
/// 获取特定版本的安装路径
pub fn version_dir(tool : Tool, version : String) -> String raise {
  @fs_ext.join_path(tool_dir(tool), version)
}

///|
/// 下载信息结构体，包含下载 URL、请求 headers 和压缩包目录深度
pub struct DownloadInfo {
  // 下载地址
  url : String
  // 下载请求需要携带的 headers
  headers : Map[String, String]
  // 压缩包解压出来之后，需要进入多少层级才能到达实际工具根目录
  // 一般的压缩包会有1层目录，某些压缩包没有包装一层根目录，返回0即可
  root_path_depth : UInt
} derive(Debug)

///|
/// 检查版本是否已安装
pub async fn is_installed(tool : Tool, version : String) -> Bool {
  let tool_exe_path = match tool {
    Java => Java::get_exe_path(version)
    Deno => Deno::get_exe_path(version)
    Rust => Rust::get_exe_path(version)
    Python | Python3 => Python::get_exe_path(version)
    Go => Go::get_exe_path(version)
    Zig => Zig::get_exe_path(version)
    Bun => Bun::get_exe_path(version)
    Node => NodePath(version).get_exe_path(Node.to_string())
    Kotlin => Kotlin::get_exe_path(version)
  }
  if @fs.exists(tool_exe_path) {
    return true
  }
  if tool is Rust {
    let os = @os.get_os_name()
    let suffix = if os is Windows { ".exe" } else { "" }
    let base = version_dir(Tool::Rust, version)
    let old_path = @fs_ext.join_paths([base, "bin", "rustc\{suffix}"])
    if @fs.exists(old_path) {
      return true
    }
  }
  false
}

///|
pub(all) enum Tool {
  Node
  Bun
  Zig
  Go
  Python
  Python3
  Rust
  Deno
  Java
  Kotlin
} derive(Debug)

///|
pub impl @utils.ToStr for Tool with fn to_str(s) {
  match s {
    Node => "node"
    Bun => "bun"
    Zig => "zig"
    Go => "go"
    Python => "python"
    Python3 => "python3"
    Rust => "rust"
    Deno => "deno"
    Java => "java"
    Kotlin => "kotlin"
  }
}

///|
/// 所有工具列表（包含 Node 内置工具），用于创建 wrapper 脚本
pub fn Tool::all_tools() -> Array[Tool] {
  [Node, Bun, Zig, Go, Python, Python3, Rust, Deno, Java, Kotlin]
}

///|
/// 可安装的工具列表（不包含内置工具）
pub fn Tool::installable_tools() -> Array[Tool] {
  [Node, Bun, Zig, Go, Python, Python3, Rust, Deno, Java, Kotlin]
}

///|
pub impl Show for Tool with fn output(s, logger) {
  logger.write_string(s.to_str())
}

///|
pub fn Tool::from_string(tool : String) -> Tool raise {
  match tool.to_lower() {
    "node" => Node
    "bun" => Bun
    "zig" => Zig
    "go" => Go
    "python" => Python
    "python3" => Python3
    "rust" | "rustc" => Rust
    "deno" => Deno
    "java" | "jdk" => Java
    "kotlin" => Kotlin
    _ => raise fail(@i18n.t("error.unsupported_tool", args={ "tool": tool }))
  }
}

///|
pub fn Tool::from_string_with_option_result(tool : String) -> Tool? {
  let tool = Tool::from_string(tool) catch { _ => return None }
  Some(tool)
}

///|
let node_executable_programs : ReadOnlyArray[String] = [
  "node", "npm", "npx", "corepack",
]

///|
let bun_executable_programs : ReadOnlyArray[String] = ["bun", "bunx"]

///|
let zig_executable_programs : ReadOnlyArray[String] = ["zig"]

///|
let go_executable_programs : ReadOnlyArray[String] = ["go", "gofmt"]

///|
let python_executable_programs : ReadOnlyArray[String] = ["python"]

///|
let python3_executable_programs : ReadOnlyArray[String] = ["python3"]

///|
let rust_executable_programs : ReadOnlyArray[String] = [
  "rustc", "cargo", "rustfmt", "cargo-fmt", "clippy-driver", "cargo-clippy", "rustdoc",
  "rust-gdb", "rust-gdbgui", "rust-lldb", "rust-analyzer",
]

///|
let deno_executable_programs : ReadOnlyArray[String] = ["deno"]

///|
let java_executable_programs : ReadOnlyArray[String] = [
  "java", "javac", "jar", "javadoc", "jps", "jcmd", "jstat", "keytool",
]

///|
let kotlin_executable_programs : ReadOnlyArray[String] = ["kotlin", "kotlinc"]

///|
/// 获取工具的所有可执行命令名
/// 例如 Rust 的可执行命令是 rustc、cargo 等（rust 本身不是可执行命令）
/// 用于创建 shim 脚本和设置可执行权限
pub fn Tool::get_executable_programs(tool : Tool) -> ReadOnlyArray[String] {
  match tool {
    Node => node_executable_programs
    Bun => bun_executable_programs
    Zig => zig_executable_programs
    Go => go_executable_programs
    Python => python_executable_programs
    Python3 => python3_executable_programs
    // Rust 本身不是可执行命令，实际可执行的是 rustc、cargo 等
    Rust => rust_executable_programs
    Deno => deno_executable_programs
    Java => java_executable_programs
    Kotlin => kotlin_executable_programs
  }
}

///|
pub fn Tool::get_belonging_tool(cmd : String) -> Tool raise {
  let lower_name = cmd.to_lower()
  if node_executable_programs.contains(lower_name) {
    Node
  } else if bun_executable_programs.contains(lower_name) {
    Bun
  } else if zig_executable_programs.contains(lower_name) {
    Zig
  } else if go_executable_programs.contains(lower_name) {
    Go
  } else if python3_executable_programs.contains(lower_name) {
    Python3
  } else if python_executable_programs.contains(lower_name) {
    Python
  } else if rust_executable_programs.contains(lower_name) {
    Rust
  } else if deno_executable_programs.contains(lower_name) {
    Deno
  } else if java_executable_programs.contains(lower_name) {
    Java
  } else if kotlin_executable_programs.contains(lower_name) {
    Kotlin
  } else {
    raise fail(@i18n.t("error.unrecognized_command", args={ "cmd": cmd }))
  }
}

///|
test "Tool::from_string 所有工具" {
  guard Tool::from_string("node") is Node else { fail("expected Node") }
  guard Tool::from_string("bun") is Bun else { fail("expected Bun") }
  guard Tool::from_string("zig") is Zig else { fail("expected Zig") }
  guard Tool::from_string("go") is Go else { fail("expected Go") }
  guard Tool::from_string("python") is Python else { fail("expected Python") }
  guard Tool::from_string("python3") is Python3 else {
    fail("expected Python3")
  }
  guard Tool::from_string("rust") is Rust else { fail("expected Rust") }
  guard Tool::from_string("rustc") is Rust else { fail("expected Rust") }
  guard Tool::from_string("deno") is Deno else { fail("expected Deno") }
  guard Tool::from_string("java") is Java else { fail("expected Java") }
  guard Tool::from_string("jdk") is Java else { fail("expected Java") }
  guard Tool::from_string("kotlin") is Kotlin else { fail("expected Kotlin") }
  // 大小写不敏感
  guard Tool::from_string("NODE") is Node else { fail("expected Node") }
  guard Tool::from_string("Bun") is Bun else { fail("expected Bun") }
  guard Tool::from_string("PYTHON") is Python else { fail("expected Python") }
  guard Tool::from_string("RUST") is Rust else { fail("expected Rust") }
  guard Tool::from_string("DENO") is Deno else { fail("expected Deno") }
  guard Tool::from_string("JAVA") is Java else { fail("expected Java") }
  guard Tool::from_string("KOTLIN") is Kotlin else { fail("expected Kotlin") }
}

///|
test "Tool::from_string 无效工具" {
  guard @utils.to_result(() => Tool::from_string("foobar")) is Err(_) else {
    fail("invalid tool should raise error")
  }
}

///|
test "Tool::from_string_with_option_result" {
  guard Tool::from_string_with_option_result("node") is Some(Node) else {
    fail("expected Some(Node)")
  }
  guard Tool::from_string_with_option_result("python") is Some(Python) else {
    fail("expected Some(Python)")
  }
  guard Tool::from_string_with_option_result("python3") is Some(Python3) else {
    fail("expected Some(Python3)")
  }
  guard Tool::from_string_with_option_result("rust") is Some(Rust) else {
    fail("expected Some(Rust)")
  }
  guard Tool::from_string_with_option_result("deno") is Some(Deno) else {
    fail("expected Some(Deno)")
  }
  guard Tool::from_string_with_option_result("java") is Some(Java) else {
    fail("expected Some(Java)")
  }
  guard Tool::from_string_with_option_result("kotlin") is Some(Kotlin) else {
    fail("expected Some(Kotlin)")
  }
  guard Tool::from_string_with_option_result("foobar") is None else {
    fail("expected None for invalid tool")
  }
}

///|
/// 程序的可执行文件信息结构体
pub struct ProgramExeInfo {
  // 命令的名称，例如 node、npm、cargo 等
  name : String
  // 程序的可执行文件路径
  path : String
  // 程序的版本（例如 npm 包的版本号）
  version : String
  // 工具的版本（例如 Node.js 的版本号，用于定位工具安装目录）
  tool_version : String
  // 运行程序需要的环境变量
  envs : Map[String, String]
  program_exists : Bool
  // 命令对应的工具
  tool : Tool
  tool_exists : Bool
  // 额外的参数（例如 .js 文件路径，需要在可执行文件之后、用户参数之前插入）
  extra_args : Array[String]
} derive(Debug)

///|
pub fn ProgramExeInfo::ProgramExeInfo(
  name : String,
  path : String,
  version : String,
  tool_version : String,
  envs? : Map[String, String] = Map([]),
  program_exists : Bool,
  tool : Tool,
  tool_exists : Bool,
  extra_args? : Array[String] = [],
) -> ProgramExeInfo {
  {
    name,
    tool,
    path,
    version,
    tool_version,
    envs,
    program_exists,
    tool_exists,
    extra_args,
  }
}

///|
/// Format OS compatibility error message with template variables
/// Supported variables: {version}, {os.name}, {os.arch}
fn format_os_compat_error(
  error_msg_tpl : String,
  version : String,
  os : @os.OsInfo,
) -> String {
  error_msg_tpl
  .replace_all(old="{version}", new=@utils.yellow(version))
  .replace_all(old="{os.name}", new=@utils.yellow(os.name.to_string()))
  .replace_all(old="{os.arch}", new=@utils.yellow(os.arch.to_string()))
}

///|
pub async fn create_tool_cmd_unix(
  tool : Tool,
  cmd_name : String,
  file_name? : String = cmd_name,
  cmd_dir? : String = "",
) -> Unit {
  // 创建一个shell文件（不需要.sh后缀），里面执行mvm run {tool} -- {cmd_name} "$@"
  let mvm_bin = mvm_bin_home()
  let shell_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, file_name])
  let tool_name = tool.to_string()
  let shell_content = "#!/bin/sh\nmvm run \{tool_name} \{cmd_name} \"$@\""
  @fs.write_file(shell_file_path, shell_content, create_mode=CreateOrTruncate)
  // 添加可执行权限
  @mvm_cmd.chmod_x([shell_file_path])
  @log.debug(
    @i18n.t("tool.debug_create_shell", args={ "path": shell_file_path }),
  )
}

///|
pub async fn create_tool_cmd_windows(
  tool : Tool,
  cmd_name : String,
  file_name? : String = cmd_name,
  cmd_dir? : String = "",
) -> Unit {
  let mvm_bin = mvm_bin_home()
  let tool_name = tool.to_string()
  let ps1_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, "\{file_name}.ps1"])
  let cmd_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, "\{file_name}.cmd"])
  let bash_file_path = @fs_ext.join_paths([mvm_bin, cmd_dir, file_name])
  let ps1_content = "mvm run \{tool_name} \{cmd_name} $args"
  let cmd_content = "@mvm run \{tool_name} \{cmd_name} %*"
  let bash_content = "#!/bin/sh\nmvm run \{tool_name} \{cmd_name} \"$@\""
  @fs.write_file(ps1_file_path, ps1_content, create_mode=CreateOrTruncate)
  @fs.write_file(cmd_file_path, cmd_content, create_mode=CreateOrTruncate)
  @fs.write_file(bash_file_path, bash_content, create_mode=CreateOrTruncate)
  @mvm_cmd.chmod_x([bash_file_path])
  @log.debug(@i18n.t("tool.debug_create_ps1", args={ "path": ps1_file_path }))
  @log.debug(@i18n.t("tool.debug_create_cmd", args={ "path": cmd_file_path }))
  @log.debug(@i18n.t("tool.debug_create_bash", args={ "path": bash_file_path }))
}
