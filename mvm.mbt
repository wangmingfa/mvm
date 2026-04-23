// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
/// MVM 主目录
pub fn mvm_home() -> String {
  guard @env.get_env_var("HOME") is Some(home)
  "\{home}/.mvm"
}

///|
/// 工具安装目录
pub fn tools_dir() -> String {
  "\{mvm_home()}/tools"
}

///|
/// 获取特定工具的安装目录
pub fn tool_dir(tool : Tool) -> String {
  "\{tools_dir()}/\{tool.to_string().to_lower()}"
}

///|
/// 获取特定版本的安装路径
pub fn version_dir(tool : Tool, version : String) -> String {
  "\{tool_dir(tool)}/\{version}"
}

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
  // Bun
  Zig
}

///|
pub impl Show for Tool with to_string(s) {
  match s {
    // Bun => "Bun"
    Npm => "Npm"
    Node => "Node"
    Zig => "Zig"
  }
}

///|
pub impl Show for Tool with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
fn Tool::from_string(tool : String) -> Tool raise {
  match tool.to_lower() {
    "node" => Node
    "npm" => Npm
    // "bun" => Bun
    "zig" => Zig
    _ => raise fail("无效的工具：\{tool}")
  }
}

///|
pub struct Version(String)

///|
/// 获取版本号字符串
pub fn Version::value(self : Version) -> String {
  self.0
}

///|
impl Show for Version with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for Version with to_string(s) {
  "Version(\"\{s.0}\")"
}

///|
/// 项目配置文件名
pub fn project_config_file() -> String {
  /// 格式：
  /// {
  /// "node": "20.0.1",
  /// "zig": "0.15.1"
  /// }
  "mvm.json"
}

///|
/// 检查项目配置文件是否存在
pub async fn has_project_config() -> Bool {
  @fs.exists(project_config_file())
}

///|
struct Config {
  node : String?
  npm : String?
  bun : String?
  zig : String?
} derive(FromJson, ToJson)

///|
/// 读取项目配置
pub async fn read_project_config() -> Config? {
  if has_project_config() {
    let config = @fs.read_file(project_config_file()).json() catch {
      e => raise fail("文件\{project_config_file()}格式不对：\{e}")
    }
    Some(@json.from_json(config))
  } else {
    None
  }
}

///|
/// 写入项目配置
pub async fn write_project_config(tool : Tool, version : String) -> Unit {
  let config = read_project_config()
  let config = if config is Some(config) {
    let json = config.to_json()
    guard json is Object(map) else { {} }
    map
  } else {
    {}
  }
  let key = tool.to_string()
  let value = version
  config.set(key, Json::string(value))
  let content = Json::object(config).stringify(indent=2)
  @fs.write_file(project_config_file(), content)
}

///|
pub enum Command {
  Install(Tool, Version)
  Pin(Tool, Version)
  Use(Tool, Version)
  List(Tool?)
  Uninstall(Tool, Version)
}

///|
pub impl Show for Command with to_string(s) {
  match s {
    Install(tool, version) =>
      "Install(\{tool.to_string()}, \{version.to_string()})"
    Pin(tool, version) => "Pin(\{tool.to_string()}, \{version.to_string()})"
    Use(tool, version) => "Use(\{tool.to_string()}, \{version.to_string()})"
    List(Some(tool)) => "List(\{tool.to_string()})"
    List(None) => "List(All)"
    Uninstall(tool, version) =>
      "Uninstall(\{tool.to_string()}, \{version.to_string()})"
  }
}

///|
pub impl Show for Command with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
fn Command::new_with_version(
  command_type : String,
  tool : String,
  version : String,
) -> Command raise {
  let t = Tool::from_string(tool)
  let v = Version(version)
  match command_type {
    "install" => Install(t, v)
    "pin" => Pin(t, v)
    "use" => Use(t, v)
    "uninstall" => Uninstall(t, v)
    _ => raise fail("无效的命令类型：\{command_type}")
  }
}

///|
fn parse_with_version(command_type : String, options : String) -> Command raise {
  lexmatch options {
    (before, "@", after) =>
      Command::new_with_version(
        command_type,
        before.to_string(),
        after.to_string(),
      )
    _ => raise fail("无效的参数：\{options}，格式应为 tool@version")
  }
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  match argv {
    ["install", options] => parse_with_version("install", options)
    ["pin", options] => parse_with_version("pin", options)
    ["use", options] => parse_with_version("use", options)
    ["uninstall", options] => parse_with_version("uninstall", options)
    ["list"] => List(None)
    ["list", tool] => List(Some(Tool::from_string(tool)))
    [cmd] => raise fail("命令 '\{cmd}' 缺少参数")
    [] => raise fail("请提供命令参数。示例：mvm install node@22")
    _ => {
      let msg = argv.join(" ")
      raise fail("无效的命令：\{msg}")
    }
  }
}
