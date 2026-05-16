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
  guard home is Some(home) else {
    raise fail(
      "无法获取用户主目录，请确保环境变量 HOME 已设置",
    )
  }
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
pub fn tools_dir() -> String raise {
  "\{mvm_home()}/tools"
}

///|
/// 获取特定工具的安装目录
pub fn tool_dir(tool : Tool) -> String raise {
  "\{tools_dir()}/\{tool.to_string().to_lower()}"
}

///|
/// 获取特定版本的安装路径
pub fn version_dir(tool : Tool, version : String) -> String raise {
  "\{tool_dir(tool)}/\{version}"
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
  @fs.exists(version_dir(tool, version))
}

///|
/// 获取已安装的所有版本
pub async fn installed_versions(tool : Tool) -> Array[String] {
  let dir = tool_dir(tool)
  if @fs.exists(dir) {
    @fs.readdir(dir)
  } else {
    []
  }
}

///|
pub(all) enum Tool {
  Node
  Npm
  Npx
  Corepack
  Bun
  Zig
  Go
  Python
  Rust
  Cargo
  Deno
  Java
  Javac
  Jar
  Kotlin
  Kotlinc
} derive(Debug)

///|
pub impl @utils.ToStr for Tool with to_str(s) {
  match s {
    Node => "node"
    Npm => "npm"
    Npx => "npx"
    Corepack => "corepack"
    Bun => "bun"
    Zig => "zig"
    Go => "go"
    Python => "python"
    Rust => "rust"
    Cargo => "cargo"
    Deno => "deno"
    Java => "java"
    Javac => "javac"
    Jar => "jar"
    Kotlin => "kotlin"
    Kotlinc => "kotlinc"
  }
}

///|
pub fn Tool::installable_tools() -> Array[Tool] {
  [Node, Npm, Bun, Zig, Go, Python, Rust, Deno, Java, Kotlin]
}

///|
/// 所有工具列表（包含 Node 内置工具），用于创建 wrapper 脚本
pub fn Tool::all_tools() -> Array[Tool] {
  [
    Node, Npm, Npx, Corepack, Bun, Zig, Go,
    Python, Rust, Cargo, Deno, Java, Javac, Jar, Kotlin, Kotlinc,
  ]
}

///|
pub impl Show for Tool with output(s, logger) {
  logger.write_string(s.to_str())
}

///|
pub fn Tool::from_string(tool : String) -> Tool raise {
  match tool.to_lower() {
    "node" => Node
    "npm" => Npm
    "npx" => Npx
    "corepack" => Corepack
    "bun" => Bun
    "zig" => Zig
    "go" => Go
    "python" | "python3" => Python
    "rust" | "rustc" => Rust
    "cargo" => Cargo
    "deno" => Deno
    "java" | "jdk" => Java
    "javac" => Javac
    "jar" => Jar
    "kotlin" => Kotlin
    "kotlinc" => Kotlinc
    _ => raise fail("不支持的工具：\{tool}")
  }
}

///|
pub fn Tool::from_string_with_option_result(tool : String) -> Tool? {
  let tool = Tool::from_string(tool) catch { _ => return None }
  Some(tool)
}

///|
impl Eq for Tool with equal(a, b) {
  match a {
    Node => b is Node
    Npm => b is Npm
    Npx => b is Npx
    Corepack => b is Corepack
    Bun => b is Bun
    Zig => b is Zig
    Go => b is Go
    Python => b is Python
    Rust => b is Rust
    Cargo => b is Cargo
    Deno => b is Deno
    Java => b is Java
    Javac => b is Javac
    Jar => b is Jar
    Kotlin => b is Kotlin
    Kotlinc => b is Kotlinc
  }
}

///|
pub fn Tool::is_node_builtin_tools(tool : Tool) -> Bool {
  [Npm, Npx, Corepack].contains(tool)
}

///|
/// Rust 内置工具判断（Cargo 为 Rust 的内置工具）
pub fn Tool::is_rust_builtin_tools(tool : Tool) -> Bool {
  [Cargo].contains(tool)
}

///|
/// Java 内置工具判断（Javac、Jar 为 JDK 的内置工具）
pub fn Tool::is_java_builtin_tools(tool : Tool) -> Bool {
  [Javac, Jar].contains(tool)
}

///|
/// Kotlin 内置工具判断（Kotlinc 为 Kotlin 的内置工具）
pub fn Tool::is_kotlin_builtin_tools(tool : Tool) -> Bool {
  [Kotlinc].contains(tool)
}

///|
/// 获取工具的所有可执行命令名
/// 例如 Rust 的可执行命令是 rustc、cargo 等（rust 本身不是可执行命令）
/// 用于创建 shim 脚本和设置可执行权限
pub fn Tool::get_executable_names(tool : Tool) -> Array[String] {
  match tool {
    Node => ["node"]
    Npm => ["npm"]
    Npx => ["npx"]
    Corepack => ["corepack"]
    Bun => ["bun"]
    Zig => ["zig"]
    Go => ["go", "gofmt"]
    Python => ["python3", "python"]
    // Rust 本身不是可执行命令，实际可执行的是 rustc、cargo 等
    Rust => ["rustc", "cargo", "rustfmt", "cargo-fmt", "clippy-driver", "cargo-clippy", "rustdoc"]
    Cargo => ["cargo"]
    Deno => ["deno"]
    Java => ["java", "javac", "jar", "javadoc", "jps", "jcmd", "jstat", "keytool"]
    Javac => ["javac"]
    Jar => ["jar"]
    Kotlin => ["kotlin", "kotlinc"]
    Kotlinc => ["kotlinc"]
  }
}

///|
pub fn Tool::get_belonging_tools(tool : Tool) -> Tool {
  if Tool::is_node_builtin_tools(tool) {
    Node
  } else if Tool::is_rust_builtin_tools(tool) {
    Rust
  } else if Tool::is_java_builtin_tools(tool) {
    Java
  } else if Tool::is_kotlin_builtin_tools(tool) {
    Kotlin
  } else {
    tool
  }
}

///|
test "Tool::from_string 所有工具" {
  guard Tool::from_string("node") is Node else { fail("expected Node") }
  guard Tool::from_string("npm") is Npm else { fail("expected Npm") }
  guard Tool::from_string("npx") is Npx else { fail("expected Npx") }
  guard Tool::from_string("corepack") is Corepack else {
    fail("expected Corepack")
  }
  guard Tool::from_string("bun") is Bun else { fail("expected Bun") }
  guard Tool::from_string("zig") is Zig else { fail("expected Zig") }
  guard Tool::from_string("go") is Go else { fail("expected Go") }
  guard Tool::from_string("python") is Python else {
    fail("expected Python")
  }
  guard Tool::from_string("python3") is Python else {
    fail("expected Python")
  }
  guard Tool::from_string("rust") is Rust else { fail("expected Rust") }
  guard Tool::from_string("rustc") is Rust else { fail("expected Rust") }
  guard Tool::from_string("cargo") is Cargo else { fail("expected Cargo") }
  guard Tool::from_string("deno") is Deno else { fail("expected Deno") }
  guard Tool::from_string("java") is Java else { fail("expected Java") }
  guard Tool::from_string("jdk") is Java else { fail("expected Java") }
  guard Tool::from_string("javac") is Javac else { fail("expected Javac") }
  guard Tool::from_string("jar") is Jar else { fail("expected Jar") }
  guard Tool::from_string("kotlin") is Kotlin else {
    fail("expected Kotlin")
  }
  guard Tool::from_string("kotlinc") is Kotlinc else {
    fail("expected Kotlinc")
  }
  // 大小写不敏感
  guard Tool::from_string("NODE") is Node else { fail("expected Node") }
  guard Tool::from_string("Bun") is Bun else { fail("expected Bun") }
  guard Tool::from_string("PYTHON") is Python else {
    fail("expected Python")
  }
  guard Tool::from_string("RUST") is Rust else { fail("expected Rust") }
  guard Tool::from_string("DENO") is Deno else { fail("expected Deno") }
  guard Tool::from_string("JAVA") is Java else { fail("expected Java") }
  guard Tool::from_string("KOTLIN") is Kotlin else {
    fail("expected Kotlin")
  }
}

///|
test "Tool::from_string 无效工具" {
  guard (try? Tool::from_string("foobar")) is Err(_) else {
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
pub struct ToolExe {
  tool : Tool
  // 工具的可执行文件路径
  path : String
  // 工具的版本
  version : String
  // 运行工具需要的环境变量
  envs : Map[String, String]
  // 依赖的其它工具
  // 比如npm、npx、corepack是依赖node的
  dependent_tool_exe : ToolExe?
} derive(Debug)

///|
pub fn ToolExe::new(
  tool : Tool,
  path : String,
  version : String,
  envs? : Map[String, String] = {},
  dependent_tool_exe? : ToolExe? = None,
) -> ToolExe {
  { tool, path, version, envs, dependent_tool_exe }
}

///|
pub fn ToolExe::new_node_builtin_tool(
  tool : Tool,
  node_tool_exe : ToolExe,
  path : String,
  version : String,
  envs? : Map[String, String] = {},
) -> ToolExe {
  ToolExe::new(
    tool,
    path,
    version,
    envs~,
    dependent_tool_exe=Some(node_tool_exe),
  )
}

///|
/// Format OS compatibility error message with template variables
/// Supported variables: {version}, {os.name}, {os.arch}
pub fn format_os_compat_error(
  error_msg_tpl : String,
  version : String,
  os : @os.OsInfo,
) -> String {
  error_msg_tpl
  .replace_all(old="{version}", new=@utils.yellow(version))
  .replace_all(old="{os.name}", new=@utils.yellow(os.name.to_string()))
  .replace_all(old="{os.arch}", new=@utils.yellow(os.arch.to_string()))
}