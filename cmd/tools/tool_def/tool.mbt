// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
/// MVM 主目录
pub fn mvm_home() -> String {
  if @env.get_env_var("MVM_HOME") is Some(home) {
    return home
  }
  guard @env.get_env_var("HOME") is Some(home)
  @fs_ext.join_path(home, ".mvm")
}

///|
pub fn cache_dir() -> String {
  @fs_ext.join_path(mvm_home(), ".cache")
}

///|
pub async fn read_cache_file_content(cache_file_path : String) -> String? {
  let file_path = @fs_ext.join_path(cache_dir(), cache_file_path)
  if @fs.exists(file_path) {
    return Some(@fs.read_file(file_path).text())
  }
  return None
}

///|
pub async fn write_cache_file_content(
  cache_file_path : String,
  content : String,
) -> Unit {
  let file_path = @fs_ext.join_path(cache_dir(), cache_file_path)
  let parent_dir = @fs_ext.get_parent_dir(file_path)
  guard parent_dir is Some(parent_dir)
  @fs_ext.ensure_dir(parent_dir)
  @fs.write_file(file_path, content, create_mode=CreateOrTruncate)
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
  Npx
  Corepack
  Bun
  Zig
}

///|
pub fn Tool::all() -> Array[Tool] {
  [Node, Npm, Zig]
}

///|
pub impl Show for Tool with to_string(s) {
  match s {
    Node => "node"
    Npm => "npm"
    Npx => "npx"
    Corepack => "corepack"
    Bun => "bun"
    Zig => "zig"
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
    "npx" => Npx
    "corepack" => Corepack
    "bun" => Bun
    "zig" => Zig
    _ => raise fail("不支持的工具：\{tool}")
  }
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
  }
}

///|
pub fn Tool::is_node_builtin_tools(tool : Tool) -> Bool {
  [Npm, Npx, Corepack].contains(tool)
}

///|
const CONFIG_FILE = "mvm.json"

///|
pub async fn get_config(
  tool? : Tool,
  dir? : String,
  search_upwards? : Bool = true,
  fallback_to_global_config? : Bool = true,
) -> (String, Config)? {
  let dir = if dir is Some(dir) {
    dir
  } else {
    guard @env.current_dir() is Some(dir)
    dir
  }
  if tool is Some(t) {
    get_config_inner(Some(t), dir, search_upwards, fallback_to_global_config)
  } else {
    get_config_inner(None, dir, search_upwards, fallback_to_global_config)
  }
}

///|
/// 检查项目配置文件是否存在
async fn get_config_inner(
  tool : Tool?,
  dir : String,
  search_upwards : Bool,
  fallback_to_global_config : Bool,
) -> (String, Config)? {
  let path = @fs_ext.join_path(dir, CONFIG_FILE)
  @log.debug("在 \{dir} 查找 \{tool} 的版本号")
  if @fs.exists(path) {
    let json = @fs.read_file(path).json() catch {
      _ => {
        println("文件 \{@utils.red(path)} 不是有效的json格式")
        return None
      }
    }
    let config : Config = @json.from_json(json) catch {
      _ => {
        println("文件 \{@utils.red(path)} 有效")
        return None
      }
    }
    // println("json: \{json}")
    // println("config: \{config}")
    if tool is Some(tool) {
      // 指定了tool
      if json is Object(map) &&
        map.get(tool.to_string()) is Some(String(version)) {
        // 有版本
        @log.debug("在 \{path} 找到 \{tool} 版本 \{version}")
        return Some((path, config))
      }
    } else {
      // 没有指定tool
      return Some((path, config))
    }
  }
  if dir == mvm_home() {
    return None
  }
  // 往上一级
  guard @fs_ext.get_parent_dir(dir) is Some(parent) else {
    return if fallback_to_global_config {
      @log.debug("从 MVM_HOME 查找")
      // 没有上一级，则从mvm_home找
      get_config_inner(
        tool,
        mvm_home(),
        search_upwards,
        fallback_to_global_config,
      )
    } else {
      None
    }
  }
  if search_upwards {
    @log.debug("从父目录查找")
    return get_config_inner(
      tool, parent, search_upwards, fallback_to_global_config,
    )
  }
  None
}

///|
pub struct Config {
  node : String?
  bun : String?
  zig : String?
} derive(FromJson, ToJson)

///|
impl Show for Config with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for Config with to_string(s) {
  (
    $|{node: \{s.node}, bun: \{s.bun}, zig: \{s.zig}}
  )
}

///|
pub fn Config::get_value(self : Self, tool : Tool) -> String? raise {
  match tool {
    Node => self.node
    Zig => self.zig
    _ => raise fail("不支持获取 \{tool} 的值")
  }
}

///|
test "Config from_json" {
  let json : Json = { "node": "v20.1.1" }
  let config : Config = @json.from_json(json)
  inspect(
    config,
    content=(
      #|{node: Some("v20.1.1"), npm: None, bun: None, zig: None}
    ),
  )
}

///|
fn get_project_config_path() -> String {
  guard @env.current_dir() is Some(cwd)
  return @fs_ext.join_path(cwd, CONFIG_FILE)
}

///|
fn get_global_config_path() -> String {
  @fs_ext.join_path(mvm_home(), CONFIG_FILE)
}

///|
async fn write_config(
  config_file_path : String,
  tool : Tool,
  version : String,
) -> String {
  let json = if @fs.exists(config_file_path) {
    @fs.read_file(config_file_path).json()
  } else {
    {}
  }
  guard json is Object(map) else {
    raise fail("文件 \{config_file_path} 不是有效的json格式")
  }
  let key = tool.to_string()
  let value = version
  map.set(key, Json::string(value))
  let content = Json::object(map).stringify(indent=2)
  @fs.write_file(config_file_path, content, create_mode=CreateOrTruncate)
  config_file_path
}

///|
/// 写入项目配置
pub async fn write_project_config(tool : Tool, version : String) -> String {
  let config_file_path = get_project_config_path()
  write_config(config_file_path, tool, version)
}

///|
pub async fn write_global_config(tool : Tool, version : String) -> String {
  let config_file_path = get_global_config_path()
  write_config(config_file_path, tool, version)
}
