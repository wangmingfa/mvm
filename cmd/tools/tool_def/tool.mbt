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
pub fn cache_dir() -> String raise {
  @fs_ext.join_path(mvm_home(), ".cache")
}

///|
pub fn temp_dir() -> String raise {
  @fs_ext.join_path(mvm_home(), ".temp")
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
  }
}

///|
pub fn Tool::installable_tools() -> Array[Tool] {
  [Node, Npm, Bun, Zig, Go]
}

///|
/// 所有工具列表（包含 Node 内置工具），用于创建 wrapper 脚本
pub fn Tool::all_tools() -> Array[Tool] {
  [Node, Npm, Npx, Corepack, Bun, Zig, Go]
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
  }
}

///|
pub fn Tool::is_node_builtin_tools(tool : Tool) -> Bool {
  [Npm, Npx, Corepack].contains(tool)
}

///|
pub fn Tool::get_belonging_tools(tool : Tool) -> Tool {
  if Tool::is_node_builtin_tools(tool) {
    Node
  } else {
    tool
  }
}

///|
const CONFIG_FILE = "mvm.json"

///|
const VOLTA_CONFIG_FILE = "package.json"

///|
const GLOBAL_SETTINGS_FILE = "config.json"

///|
/// config.json 配置说明
///
/// 支持的变量：
/// - `$URL` - 原始下载链接
/// - `$TOOL` - 工具名（如 node, npm, bun, zig）
/// - `$VERSION` - 版本号（如 v20.1.0）
/// - `$OS` - 操作系统（如 darwin, linux, windows）
/// - `$ARCH` - 架构（如 x64, arm64）
///
/// 示例配置：
/// {
///   "github_proxy": "https://cdn.gh-proxy.org/$URL"
/// }
pub(all) struct GlobalConfig {
  github_proxy : String?
  node_mirror : String?
  go_mirror : String?
} derive(FromJson, ToJson)

///|
pub fn make_global_config(
  existing_config? : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
  },
  github_proxy? : String? = None,
  node_mirror? : String? = None,
  go_mirror? : String? = None,
) -> GlobalConfig {
  let github_proxy = if github_proxy is Some(v) {
    Some(v)
  } else {
    existing_config.github_proxy
  }
  let node_mirror = if node_mirror is Some(v) {
    Some(v)
  } else {
    existing_config.node_mirror
  }
  let go_mirror = if go_mirror is Some(v) {
    Some(v)
  } else {
    existing_config.go_mirror
  }
  { github_proxy, node_mirror, go_mirror }
}

///|
pub fn GlobalConfig::to_string(s : Self, indent? : Int = 0) -> String {
  let indent_str = " ".repeat(indent)
  let github_proxy = s.github_proxy.unwrap_or("")
  let node_mirror = s.node_mirror.unwrap_or("")
  let go_mirror = s.go_mirror.unwrap_or("")
  (
    $|\{indent_str}github_proxy: \{github_proxy}
    $|\{indent_str}node_mirror: \{node_mirror}
    $|\{indent_str}go_mirror: \{go_mirror}
  )
}

///|
fn get_global_settings_path() -> String raise {
  @fs_ext.join_path(mvm_home(), GLOBAL_SETTINGS_FILE)
}

///|
pub async fn get_global_config() -> (String, GlobalConfig) {
  let config_path = @fs_ext.canonicalize_path(get_global_settings_path())
  if @fs.exists(config_path) {
    let json = @fs.read_file(config_path).json() catch {
      _ =>
        raise fail(
          "文件 \{@utils.red(config_path)} 不是有效的json格式",
        )
    }
    let config : GlobalConfig = @json.from_json(json) catch {
      _ => raise fail("文件 \{@utils.red(config_path)} 格式无效")
    }
    (config_path, config)
  } else {
    (config_path, { github_proxy: None, node_mirror: None, go_mirror: None })
  }
}

///|
pub async fn save_global_config(config : GlobalConfig) -> String {
  let config_path = get_global_settings_path()
  let content = config.to_json().stringify(indent=2)
  @fs.write_file(config_path, content, create_mode=CreateOrTruncate)
  config_path
}

///|
/// URL 替换上下文
pub struct UrlReplaceContext {
  url : String
  tool : String
  version : String
  os : String
  arch : String
}

///|
pub fn UrlReplaceContext::new(
  url : String,
  tool : String,
  version : String,
  os : String,
  arch : String,
) -> UrlReplaceContext {
  { url, tool, version, os, arch }
}

///|
/// 替换 URL 中的变量
/// 支持的变量：$URL, $TOOL, $VERSION, $OS, $ARCH
pub fn replace_url(template : String, ctx : UrlReplaceContext) -> String {
  let result = template
  result
  .replace(old="$URL", new=ctx.url)
  .replace(old="$TOOL", new=ctx.tool)
  .replace(old="$VERSION", new=ctx.version)
  .replace(old="$OS", new=ctx.os)
  .replace(old="$ARCH", new=ctx.arch)
}

///|
/// 应用全局配置转换 URL
/// node_mirror: 用于 Node.js 镜像（优先级高于 github_proxy）
/// github_proxy: 用于 GitHub 相关下载（如 node index.json）
pub fn apply_global_config(
  url : String,
  config : GlobalConfig,
  ctx : UrlReplaceContext,
) -> String {
  match config.node_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "node" => {
      @log.debug("使用 Node 镜像: \{mirror}")
      return url.replace(old=NODE_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.go_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "go" => {
      @log.debug("使用 Go 镜像: \{mirror}")
      return url.replace(old=GO_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.github_proxy {
    Some(proxy) if proxy != "" && url.has_prefix("https://github.com/") => {
      @log.debug("使用 GitHub 代理: \{proxy}")
      return replace_url(proxy, ctx)
    }
    _ => ()
  }
  url
}

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
/// 优先从 mvm.json 获取配置，如果没有则尝试从 Volta package.json 获取（仅支持 Node）
async fn get_config_inner(
  tool : Tool?,
  dir : String,
  search_upwards : Bool,
  fallback_to_global_config : Bool,
) -> (String, Config)? {
  let mvm_path = @fs_ext.join_path(dir, CONFIG_FILE)
  @log.debug("在 \{dir} 查找 \{@utils.option_to_string(tool)} 的版本号")

  // 优先从 mvm.json 获取
  if @fs.exists(mvm_path) {
    let json = @fs.read_file(mvm_path).json() catch {
      _ =>
        raise fail("文件 \{@utils.red(mvm_path)} 不是有效的json格式")
    }
    let config : Config = @json.from_json(json) catch {
      _ => raise fail("文件 \{@utils.red(mvm_path)} 有效")
    }
    if tool is Some(t) {
      if json is Object(map) && map.get(t.to_string()) is Some(String(version)) {
        @log.debug("在 \{mvm_path} 找到 \{t} 版本 \{version}")
        return Some((mvm_path, config))
      }
    } else {
      return Some((mvm_path, config))
    }
  }

  // mvm.json 中没有该工具的配置，尝试从 Volta package.json 获取（仅支持 Node）
  if tool is Some(Node) {
    match get_node_version_from_volta_package_json(dir) {
      Some(volta_version) => {
        let volta_config : Config = {
          node: Some(volta_version),
          bun: None,
          zig: None,
          go: None,
        }
        let volta_path = @fs_ext.join_path(dir, VOLTA_CONFIG_FILE)
        @log.debug(
          "从 Volta package.json 找到 node 版本: \{volta_version}",
        )
        return Some((volta_path, volta_config))
      }
      None => ()
    }
  }

  if dir == mvm_home() {
    return None
  }
  // 往上一级
  guard @fs_ext.get_parent_dir(dir) is Some(parent) else {
    return if fallback_to_global_config {
      @log.debug("从 MVM_HOME 查找")
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
  go : String?
} derive(FromJson, ToJson)

///|
impl Show for Config with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for Config with to_string(s) {
  (
    $|{node: \{@utils.option_to_string(s.node)}, bun: \{@utils.option_to_string(s.bun)}, zig: \{@utils.option_to_string(s.zig)}, go: \{@utils.option_to_string(s.go)}}
  )
}

///|
pub fn Config::get_value(self : Self, tool : Tool) -> String? raise {
  match tool {
    Node => self.node
    Bun => self.bun
    Zig => self.zig
    Go => self.go
    _ => raise fail("不支持获取 \{tool} 的值")
  }
}

///|
/// 从 Volta package.json 获取 node 版本
/// Volta 格式: { "volta": { "node": "20.0.0" } }
async fn get_node_version_from_volta_package_json(dir : String) -> String? {
  let path = @fs_ext.join_path(dir, VOLTA_CONFIG_FILE)
  if !@fs.exists(path) {
    return None
  }
  let content = @fs.read_file(path)
  let json = content.json() catch { _ => return None }
  guard json is Object(map) else { return None }
  match map.get("volta") {
    Some(Object(volta_map)) =>
      match volta_map.get("node") {
        Some(String(version)) => {
          let version = if version.has_prefix("v") {
            version
          } else {
            "v\{version}"
          }
          @log.debug("从 Volta package.json 找到 node 版本: \{version}")
          return Some(version)
        }
        _ => return None
      }
    _ => return None
  }
}

///|
test "Config from_json" {
  let json : Json = { "node": "v20.1.1" }
  let config : Config = @json.from_json(json)
  inspect(
    config,
    content=(
      #|{node: Some("v20.1.1"), bun: None, zig: None, go: None}
    ),
  )
}

///|
fn get_project_config_path() -> String {
  guard @env.current_dir() is Some(cwd)
  return @fs_ext.join_path(cwd, CONFIG_FILE)
}

///|
fn get_global_config_path() -> String raise {
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

///|
/// 移除全局配置中指定工具的版本
pub async fn remove_global_config(tool : Tool) -> String {
  let config_file_path = get_global_config_path()
  if !@fs.exists(config_file_path) {
    raise fail("\{tool} 未设置全局版本")
  }
  let json = @fs.read_file(config_file_path).json() catch {
    _ => raise fail("文件 \{config_file_path} 不是有效的json格式")
  }
  guard json is Object(map) else {
    raise fail("文件 \{config_file_path} 格式不对")
  }
  let key = tool.to_string()
  if !map.contains(key) {
    raise fail("\{tool} 未设置全局版本")
  }
  map.remove(key)
  let content = Json::object(map).stringify(indent=2)
  @fs.write_file(config_file_path, content, create_mode=CreateOrTruncate)
  config_file_path
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

///|
/// Shared helper: resolve tool version with cache-first strategy
/// 1. If version_count == 3, try reading from cache and parsing
/// 2. If cache miss or parse result is blank, fetch from remote
/// 3. Save the remote response to cache
/// 4. Parse with the provided function
pub async fn get_target_version_with_cache(
  cache_file : String,
  url : String,
  tool_name : String,
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  parse_fn : (@os.OsInfo, String, Int, Json) -> String raise,
  headers? : Map[String, String] = {},
) -> String {
  if version_count == 3 {
    let cache_file_content = read_cache_file_content(cache_file)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = parse_fn(os, version, version_count, json) catch {
        _ => ""
      }
      if !target_version.is_blank() {
        return target_version
      }
    }
  }
  let (res, data) = @http.get(url, headers~)
  guard res.code is (200..<300) else {
    raise fail("无法获取到\{tool_name}版本信息：\{res.reason}")
  }
  let json = data.json()
  write_cache_file_content(cache_file, json.stringify(indent=2))
  parse_fn(os, version, version_count, json)
}