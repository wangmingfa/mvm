///|
/// Kotlin GitHub 发布源（用于下载，直接下载链接不受 API 速率限制）
const KOTLIN_RELEASE_URL = "https://github.com/JetBrains/kotlin/releases/download"

///|
/// Maven Central Solr 搜索 API（用于版本列表查询，无速率限制）
/// 查询 org.jetbrains.kotlin:kotlin-compiler 的所有版本，按时间倒序排列
const KOTLIN_INDEX_URL = "https://search.maven.org/solrsearch/select?q=g:org.jetbrains.kotlin+AND+a:kotlin-compiler&rows=200&wt=json&core=gav"

///|
const KOTLIN_INDEX_CACHE_FILE = "kotlin_index.json"

///|
struct Kotlin {}

///|
test "Kotlin" {
  let _ = Kotlin::{  }
}

///|
/// Maven Central 搜索 API 版本条目（每个条目包含版本号 v）
struct MavenCentralVersionDoc {
  v : String // 版本号，如 "2.2.0"、"2.1.20-RC" 等
} derive(@json.FromJson)

///|
/// Maven Central 搜索 API 响应数据（包含版本总数和版本列表）

///|
/// Maven Central 搜索 API 响应数据（仅解析 docs 字段，numFound 等额外字段会被忽略）
struct MavenCentralResponseData {
  docs : Array[MavenCentralVersionDoc]
} derive(@json.FromJson)

///|
/// Maven Central 搜索 API 响应（顶层包装）
struct MavenCentralResponse {
  response : MavenCentralResponseData
} derive(@json.FromJson)

///|
pub async fn Kotlin::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  get_target_version_with_cache(
    KOTLIN_INDEX_CACHE_FILE,
    KOTLIN_INDEX_URL,
    "Kotlin",
    os,
    version,
    version_count,
    Kotlin::_get_proper_version,
    // Maven Central API 无需 GitHub API 专用 headers
  )
}

///|
/// 判断版本号是否为稳定版（不含预发布标识：-RC, -M, -EAP, -Beta 等）
fn is_stable_version(v : String) -> Bool {
  // 稳定版本号不含 "-"（预发布版本均有如 "-RC2", "-EAP", "-M1" 等后缀）
  !v.contains("-")
}

///|
fn Kotlin::_get_proper_version(
  _os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  // 解析 Maven Central 搜索 API 响应
  let maven_response : MavenCentralResponse = @json.from_json(json) catch {
    e =>
      raise fail(
        @i18n.t("kotlin.parse_version_info_failed", args={
          "reason": e.to_string(),
        }),
      )
  }
  // 过滤出稳定版本（排除 RC、EAP、M 等预发布版本）
  let stable_versions = maven_response.response.docs
    .filter(fn(doc) { is_stable_version(doc.v) })
    .map(fn(doc) { doc.v })
  guard stable_versions.length() > 0 else {
    raise fail(@i18n.t("kotlin.stable_version_empty"))
  }
  // 按版本号倒序排序（最新版本在前）
  stable_versions.sort_by((a, b) => {
    @utils.compare_version(b, a) catch {
      _ => 0
    }
  })
  match version {
    // 空版本/lts/latest：取最新稳定版本（Kotlin 没有 LTS 概念）
    "" | "lts" | "latest" => stable_versions[0]
    _ =>
      match version_count {
        // 仅主版本号，如 "2" → 匹配最新 2.x 版本
        1 => {
          let prefix = "\{version}."
          guard stable_versions.search_by(fn(v) { v.has_prefix(prefix) })
            is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          stable_versions[idx]
        }
        // 主版本号+次版本号，如 "2.1" → 匹配最新 2.1.x 版本
        2 => {
          let prefix = "\{version}."
          guard stable_versions.search_by(fn(v) { v.has_prefix(prefix) })
            is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          stable_versions[idx]
        }
        // 精确版本号，如 "2.1.20" → 精确匹配
        3 => {
          guard stable_versions.search_by(fn(v) { v == version }) is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          stable_versions[idx]
        }
        _ =>
          raise fail(
            @i18n.t("error.invalid_version_detail", args={ "version": version }),
          )
      }
  }
}

///|
/// 获取 Kotlin 的下载信息
/// Kotlin 编译器是跨平台的单一压缩包
pub fn Kotlin::get_download_info(
  _os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo {
  // Kotlin download tag 带 v 前缀
  let ver = if version.has_prefix("v") { version } else { "v\{version}" }
  let url = "\{KOTLIN_RELEASE_URL}/\{ver}/kotlin-compiler-\{version}.zip"
  { url, headers: Map([]), root_path_depth: 1 }
}

///|
/// Kotlin 无官方 SHA256 校验文件
pub fn Kotlin::get_expected_checksum(
  _os_info : @os.OsInfo,
  _version : String,
) -> String? {
  None
}

///|
pub fn Kotlin::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".bat" } else { "" }
  [version_dir(Tool::Kotlin, version), "bin", "kotlin\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
/// 获取 Kotlin 内置工具（kotlinc）的路径和版本
pub fn Kotlin::get_kotlin_builtin_tool_path_and_version(
  tool : Tool,
  kotlin_tool_exe : ProgramExeInfo,
) -> ProgramExeInfo? {
  let { path: kotlin_exe_path, .. } = kotlin_tool_exe

  let kotlin_bin_dir : String? = @fs_ext.get_parent_dir(kotlin_exe_path) catch {
    _ => {
      @log.error(@i18n.t("error.cannot_get_bin_dir", args={ "tool": "kotlin" }))
      return None
    }
  }
  guard kotlin_bin_dir is Some(dir) else {
    @log.error(@i18n.t("error.cannot_get_bin_dir", args={ "tool": "kotlin" }))
    return None
  }
  let kotlin_bin_dir = dir

  let os = @os.get_os_name()
  let suffix = if os is Windows { ".bat" } else { "" }
  let tool_name = tool.to_string().to_lower()
  let tool_path = @fs_ext.join_path(kotlin_bin_dir, "\{tool_name}\{suffix}")

  Some(
    ProgramExeInfo(
      tool.to_str(),
      tool_path,
      kotlin_tool_exe.version,
      kotlin_tool_exe.tool_version,
      envs=kotlin_tool_exe.envs,
      true,
      kotlin_tool_exe.tool,
      kotlin_tool_exe.tool_exists,
    ),
  )
}

///|
pub async fn Kotlin::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail(@i18n.t("error.specify_program_or_version"))
  }
  let program_path = Kotlin::get_exe_path(version)
  let exists = @fs.exists(program_path)
  let kotlin_info = ProgramExeInfo(
    "kotlin",
    program_path,
    version,
    version,
    envs=Map([]),
    exists,
    Tool::Kotlin,
    exists,
  )
  let prog_low = program.to_lower()
  if prog_low == "kotlin" {
    return kotlin_info
  } else if prog_low == "kotlinc" {
    // 直接构造 ProgramExeInfo
    let os = @os.get_os_name()
    let suffix = if os is Windows { ".bat" } else { "" }
    let kotlin_bin_dir = @fs_ext.get_parent_dir(kotlin_info.path)
    match kotlin_bin_dir {
      Some(dir) => {
        let tool_path = @fs_ext.join_path(dir, "\{prog_low}\{suffix}")
        let tool_exists = @fs.exists(tool_path)
        return ProgramExeInfo(
          prog_low,
          tool_path,
          version,
          version,
          envs=Map([]),
          tool_exists,
          Tool::Kotlin,
          exists,
        )
      }
      _ => ()
    }
  }
  raise fail(
    @i18n.t("error.exe_info_not_found", args={
      "program": program,
      "version": version,
    }),
  )
}
