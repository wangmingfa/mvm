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
  python_mirror : String?
  rust_mirror : String?
  java_mirror : String?
  // deno 和 kotlin 使用 github_proxy，无专属镜像
  language : String?
  // 被 mvm 管理的工具列表，逗号分隔，如 "node,bun,go"
  // None 或空字符串表示管理所有工具（向后兼容）
  managed_tools : String?
} derive(FromJson, ToJson)

///|
pub fn make_global_config(
  existing_config? : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  },
  github_proxy? : String? = None,
  node_mirror? : String? = None,
  go_mirror? : String? = None,
  python_mirror? : String? = None,
  rust_mirror? : String? = None,
  java_mirror? : String? = None,
  language? : String? = None,
  managed_tools? : String? = None,
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
  let python_mirror = if python_mirror is Some(v) {
    Some(v)
  } else {
    existing_config.python_mirror
  }
  let rust_mirror = if rust_mirror is Some(v) {
    Some(v)
  } else {
    existing_config.rust_mirror
  }
  let java_mirror = if java_mirror is Some(v) {
    Some(v)
  } else {
    existing_config.java_mirror
  }
  let language = if language is Some(v) {
    Some(v)
  } else {
    existing_config.language
  }
  let managed_tools = if managed_tools is Some(v) {
    Some(v)
  } else {
    existing_config.managed_tools
  }
  {
    github_proxy,
    node_mirror,
    go_mirror,
    python_mirror,
    rust_mirror,
    java_mirror,
    language,
    managed_tools,
  }
}

///|
pub fn GlobalConfig::to_string(s : Self, indent? : Int = 0) -> String {
  let indent_str = " ".repeat(indent)
  let github_proxy = s.github_proxy.unwrap_or("")
  let node_mirror = s.node_mirror.unwrap_or("")
  let go_mirror = s.go_mirror.unwrap_or("")
  let python_mirror = s.python_mirror.unwrap_or("")
  let rust_mirror = s.rust_mirror.unwrap_or("")
  let java_mirror = s.java_mirror.unwrap_or("")
  let language = s.language.unwrap_or("")
  let managed_tools = s.managed_tools.unwrap_or("")
  (
    $|\{indent_str}github_proxy: \{github_proxy}
    $|\{indent_str}node_mirror: \{node_mirror}
    $|\{indent_str}go_mirror: \{go_mirror}
    $|\{indent_str}python_mirror: \{python_mirror}
    $|\{indent_str}rust_mirror: \{rust_mirror}
    $|\{indent_str}java_mirror: \{java_mirror}
    $|\{indent_str}language: \{language}
    $|\{indent_str}managed_tools: \{managed_tools}
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
          @i18n.t("error.invalid_json", args={"path": @utils.red(config_path)}),
        )
    }
    let config : GlobalConfig = @json.from_json(json) catch {
      _ => raise fail(@i18n.t("error.invalid_format", args={"path": @utils.red(config_path)}))
    }
    (config_path, config)
  } else {
    (
      config_path,
      {
        github_proxy: None,
        node_mirror: None,
        go_mirror: None,
        python_mirror: None,
        rust_mirror: None,
        java_mirror: None,
        language: None,
        managed_tools: None,
      },
    )
  }
}

///|
pub async fn save_global_config(config : GlobalConfig) -> String {
  let config_path = get_global_settings_path()
  let content = config.to_json().stringify(indent=2)
  // 原子写入：先写临时文件再 rename，避免并发读取时读到截断后的空/残缺文件
  let tmp_path = config_path + ".tmp"
  @fs.write_file(tmp_path, content, create_mode=CreateOrTruncate)
  @fs.rename(tmp_path, config_path)
  config_path
}

///|
/// 获取当前被 mvm 管理的工具列表
/// managed_tools 为 None 时返回所有工具（向后兼容）
/// managed_tools 为 Some("") 时返回空列表
/// managed_tools 为 Some("node,bun") 时返回 [Node, Bun]
pub fn get_managed_tools(global_config : GlobalConfig) -> Array[Tool] {
  match global_config.managed_tools {
    None => Tool::all_tools()
    Some(str) =>
      if str.is_blank() {
        []
      } else {
        str
        .split(",")
        .filter(v => !v.is_blank())
        .map(v => {
          let trimmed = v.trim().to_owned()
          match Tool::from_string_with_option_result(trimmed) {
            Some(tool) => Some(tool)
            None => {
              @log.warn(
                @i18n.t("error.managed_tools_unsupported", args={"names": trimmed, "tools": Tool::all_tools().map(t => t.to_string()).join(", ")}),
              )
              None
            }
          }
        })
        .filter(v => v is Some(_))
        .map(v => v.unwrap())
        .to_array()
      }
  }
}

///|
/// 校验 managed_tools 值是否合法
/// 值应为逗号分隔的工具名列表，每个工具名必须是 Tool 支持的值
/// 返回解析后的 Tool 数组；如果包含非法工具名则 raise fail
pub fn validate_managed_tools_value(value : String) -> Array[Tool] raise {
  if value.is_blank() {
    return []
  }
  let tools = []
  let invalid_names = []
  for v in value.split(",") {
    let trimmed = v.trim().to_owned()
    if trimmed.is_blank() {
      continue
    }
    match Tool::from_string_with_option_result(trimmed) {
      Some(tool) => tools.push(tool)
      None => invalid_names.push(trimmed)
    }
  }
  guard invalid_names.length() == 0 else {
    raise fail(
      @i18n.t("error.managed_tools_unsupported", args={"names": invalid_names.join(", "), "tools": Tool::all_tools().map(t => t.to_string()).join(", ")}),
    )
  }
  tools
}

///|
pub struct Config {
  node : String?
  bun : String?
  zig : String?
  go : String?
  python : String?
  rust : String?
  deno : String?
  java : String?
  kotlin : String?
} derive(FromJson, ToJson, Debug)

///|
impl Show for Config with fn output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for Config with fn to_string(s) {
  (
    $|{node: \{@utils.option_to_string(s.node)}, bun: \{@utils.option_to_string(s.bun)}, zig: \{@utils.option_to_string(s.zig)}, go: \{@utils.option_to_string(s.go)}, python: \{@utils.option_to_string(s.python)}, rust: \{@utils.option_to_string(s.rust)}, deno: \{@utils.option_to_string(s.deno)}, java: \{@utils.option_to_string(s.java)}, kotlin: \{@utils.option_to_string(s.kotlin)}}
  )
}

///|
pub fn Config::get_value(self : Self, tool : Tool) -> String? {
  match tool {
    Node => self.node
    Bun => self.bun
    Zig => self.zig
    Go => self.go
    Python => self.python
    Rust => self.rust
    Deno => self.deno
    Java => self.java
    Kotlin => self.kotlin
  }
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
  @log.debug(@i18n.t("tool.debug_find_version", args={"dir": dir, "tool": @utils.option_to_string(tool)}))

  // 优先从 mvm.json 获取
  if @fs.exists(mvm_path) {
    let json = @fs.read_file(mvm_path).json() catch {
      _ =>
        raise fail(@i18n.t("error.invalid_json", args={"path": @utils.red(mvm_path)}))
    }
    let config : Config = @json.from_json(json) catch {
      _ => raise fail(@i18n.t("error.invalid_format", args={"path": @utils.red(mvm_path)}))
    }
    if tool is Some(t) {
      if json is Object(map) && map.get(t.to_string()) is Some(String(version)) {
        @log.debug(@i18n.t("tool.debug_found_version", args={"path": mvm_path, "tool": t.to_string(), "version": version}))
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
          python: None,
          rust: None,
          deno: None,
          java: None,
          kotlin: None,
        }
        let volta_path = @fs_ext.join_path(dir, VOLTA_CONFIG_FILE)
        @log.debug(
          @i18n.t("tool.debug_volta_node_version", args={"version": volta_version}),
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
      @log.debug(@i18n.t("tool.debug_search_mvm_home"))
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
    @log.debug(@i18n.t("tool.debug_search_parent"))
    return get_config_inner(
      tool, parent, search_upwards, fallback_to_global_config,
    )
  }
  None
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
          @log.debug(@i18n.t("tool.debug_volta_node_version", args={"version": version}))
          return Some(version)
        }
        _ => return None
      }
    _ => return None
  }
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
    raise fail(@i18n.t("error.invalid_json", args={"path": config_file_path}))
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
    raise fail(@i18n.t("error.no_global_version", args={"tool": tool.to_string()}))
  }
  let json = @fs.read_file(config_file_path).json() catch {
    _ => raise fail(@i18n.t("error.invalid_json", args={"path": config_file_path}))
  }
  guard json is Object(map) else {
    raise fail(@i18n.t("error.global_version_remove_failed", args={"path": config_file_path}))
  }
  let key = tool.to_string()
  if !map.contains(key) {
    raise fail(@i18n.t("error.no_global_version", args={"tool": tool.to_string()}))
  }
  map.remove(key)
  let content = Json::object(map).stringify(indent=2)
  @fs.write_file(config_file_path, content, create_mode=CreateOrTruncate)
  config_file_path
}

///|
test "Config from_json" {
  let json : Json = { "node": "v20.1.1" }
  let config : Config = @json.from_json(json)
  guard config.node is Some("v20.1.1") else {
    fail("expected node = Some(\"v20.1.1\")")
  }
  guard config.bun is None else { fail("expected bun = None") }
  guard config.python is None else { fail("expected python = None") }
  guard config.rust is None else { fail("expected rust = None") }
  guard config.deno is None else { fail("expected deno = None") }
  guard config.java is None else { fail("expected java = None") }
  guard config.kotlin is None else { fail("expected kotlin = None") }
}

///|
test "Config from_json 多工具" {
  let json : Json = {
    "node": "v20.1.1",
    "bun": "v1.2.3",
    "zig": "v0.13.0",
    "go": "v1.23.0",
  }
  let config : Config = @json.from_json(json)
  guard config.node is Some("v20.1.1") else {
    fail("expected node = Some(\"v20.1.1\")")
  }
  guard config.bun is Some("v1.2.3") else {
    fail("expected bun = Some(\"v1.2.3\")")
  }
  guard config.zig is Some("v0.13.0") else {
    fail("expected zig = Some(\"v0.13.0\")")
  }
  guard config.go is Some("v1.23.0") else {
    fail("expected go = Some(\"v1.23.0\")")
  }
}

///|
test "Config get_value" {
  let config : Config = {
    node: Some("v20.1.1"),
    bun: Some("v1.2.3"),
    zig: None,
    go: None,
    python: None,
    rust: None,
    deno: None,
    java: None,
    kotlin: None,
  }
  guard config.get_value(Node) is Some("v20.1.1") else {
    fail("expected Some(\"v20.1.1\")")
  }
  guard config.get_value(Bun) is Some("v1.2.3") else {
    fail("expected Some(\"v1.2.3\")")
  }
  guard config.get_value(Zig) is None else { fail("expected None for zig") }
}

///|
test "GlobalConfig to_string" {
  let config : GlobalConfig = {
    github_proxy: Some("https://proxy.org/$URL"),
    node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let str = config.to_string()
  guard str.contains("github_proxy: https://proxy.org/$URL") else {
    fail("should contain github_proxy")
  }
  guard str.contains("node_mirror: https://mirrors.aliyun.com/nodejs-release") else {
    fail("should contain node_mirror")
  }
  guard str.contains("go_mirror:") else { fail("should contain go_mirror") }
}

///|
test "make_global_config 覆盖逻辑" {
  let existing : GlobalConfig = {
    github_proxy: Some("https://old-proxy.org/$URL"),
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  // 覆盖 github_proxy
  let updated = make_global_config(
    existing_config=existing,
    github_proxy=Some("https://new-proxy.org/$URL"),
  )
  guard updated.github_proxy is Some("https://new-proxy.org/$URL") else {
    fail("github_proxy should be updated")
  }
}

///|
test "get_managed_tools 返回所有工具（None 向后兼容）" {
  let config : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let tools = get_managed_tools(config)
  guard tools.length() == Tool::all_tools().length() else {
    fail("managed_tools 为 None 时应返回所有工具")
  }
}

///|
test "get_managed_tools 返回指定工具" {
  let config : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: Some("node,bun,go"),
  }
  let tools = get_managed_tools(config)
  guard tools.length() == 3 else { fail("应返回 3 个工具") }
  guard tools[0] is Node else { fail("第一个应是 Node") }
  guard tools[1] is Bun else { fail("第二个应是 Bun") }
  guard tools[2] is Go else { fail("第三个应是 Go") }
}

///|
test "get_managed_tools 空字符串返回空列表" {
  let config : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: Some(""),
  }
  let tools = get_managed_tools(config)
  guard tools.length() == 0 else { fail("空字符串应返回空列表") }
}

///|
test "get_managed_tools 非法工具名被过滤" {
  let config : GlobalConfig = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: Some("node,foobar,bun"),
  }
  let tools = get_managed_tools(config)
  guard tools.length() == 2 else {
    fail("非法名应被过滤，剩余 2 个")
  }
  guard tools[0] is Node else { fail("第一个应是 Node") }
  guard tools[1] is Bun else { fail("第二个应是 Bun") }
}

///|
test "validate_managed_tools_value 合法值" {
  let tools = validate_managed_tools_value("node,bun,go")
  guard tools.length() == 3 else { fail("应返回 3 个工具") }
  guard tools[0] is Node else { fail("第一个应是 Node") }
  guard tools[1] is Bun else { fail("第二个应是 Bun") }
  guard tools[2] is Go else { fail("第三个应是 Go") }
}

///|
test "validate_managed_tools_value 空值" {
  let tools = validate_managed_tools_value("")
  guard tools.length() == 0 else { fail("空值应返回空列表") }
}

///|
test "validate_managed_tools_value 非法值" {
  guard (try? validate_managed_tools_value("node,foobar")) is Err(_) else {
    fail("非法工具名应抛出错误")
  }
}