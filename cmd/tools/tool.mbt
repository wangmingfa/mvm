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
pub fn Tool::from_string(tool : String) -> Tool raise {
  match tool.to_lower() {
    "node" => Node
    "npm" => Npm
    // "bun" => Bun
    "zig" => Zig
    _ => raise fail("不支持的工具：\{tool}")
  }
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
const CONFIG_FILE = "mvm.json"

///|
/// 检查项目配置文件是否存在
pub async fn get_project_config_file_path(
  tool? : Tool,
  dir? : String,
) -> String? {
  let dir = if dir is Some(dir) {
    dir
  } else {
    guard @env.current_dir() is Some(dir)
    dir
  }
  let path = @fs_ext.join_path(dir, CONFIG_FILE)
  if @fs.exists(path) {
    guard tool is Some(tool) else { return Some(path) }
    let config = @fs.read_file(path).json()
    guard config is Object(map) && map.get(tool.to_string()) is Some(_) else {
      // 往上一级
      guard @fs_ext.get_parent_dir(path) is Some(parent) else { return None }
      return get_project_config_file_path(tool~, dir=parent)
    }
    // 检查是否当前工具的版本
    return Some(path)
  }
  None
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
pub async fn read_project_config(tool? : Tool) -> Config? {
  if get_project_config_file_path(tool~) is Some(path) {
    let config = @fs.read_file(project_config_file()).json() catch {
      e => raise fail("文件\{project_config_file()}格式不对：\{e}")
    }
    Some(@json.from_json(config))
  } else {
    None
  }
}
