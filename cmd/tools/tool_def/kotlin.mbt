///|
/// Kotlin GitHub 发布源
const KOTLIN_RELEASE_URL = "https://github.com/JetBrains/kotlin/releases/download"

///|
/// Kotlin GitHub releases API
const KOTLIN_INDEX_URL = "https://api.github.com/repos/JetBrains/kotlin/releases?per_page=100"

///|
const KOTLIN_INDEX_CACHE_FILE = "kotlin_index.json"

///|
struct Kotlin {}

///|
test "Kotlin" {
  let _ = Kotlin::{  }
}

///|
struct KotlinReleaseInfo {
  tag_name : String
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
    headers=@request.github_headers(),
  )
}

///|
fn Kotlin::_get_proper_version(
  _os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(arr) else { raise fail("Kotlin版本信息格式不对") }
  let infos : Array[KotlinReleaseInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e => raise fail("解析Kotlin版本信息失败，原因：\{e}")
    }
  })
  // 过滤出有效版本号（以 v 开头的标签）
  let valid_versions = infos.filter(fn(v) { v.tag_name.has_prefix("v") })
  guard valid_versions.length() > 0 else {
    raise fail("Kotlin版本信息为空")
  }
  // 按版本号倒序排序（去掉 v 前缀比较）
  valid_versions.sort_by((a, b) => {
    let a_ver = a.tag_name.sub(start=1).to_owned()
    let b_ver = b.tag_name.sub(start=1).to_owned()
    @utils.compare_version(b_ver, a_ver) catch {
      _ => 0
    }
  })
  match version {
    "" | "lts" | "latest" =>
      // Kotlin 没有 LTS 概念，取最新版本（不带 v 前缀）
      valid_versions[0].tag_name[1:].to_owned()
    _ =>
      match version_count {
        2 | 3 =>
          // Kotlin 版本号不带 v 前缀
          if version_count == 3 {
            // 精确匹配
            let search_tag = "v\{version}"
            guard valid_versions.search_by(fn(v) { v.tag_name == search_tag })
              is Some(idx) else {
              raise fail("找不到版本：\{version}")
            }
            valid_versions[idx].tag_name[1:].to_owned()
          } else {
            // 前缀匹配
            let search_tag = "v\{version}."
            guard valid_versions.search_by(fn(v) {
                v.tag_name.has_prefix(search_tag)
              })
              is Some(idx) else {
              raise fail("找不到版本：\{version}")
            }
            valid_versions[idx].tag_name[1:].to_owned()
          }
        _ => raise fail("无效的版本号：\{version}")
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
  { url, headers: {}, root_path_depth: 1 }
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
  [version_dir(Tool::Kotlin, version), "bin", "kotlinc\{suffix}"]
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
      @log.error("无法获取到 kotlin 的 bin 目录")
      return None
    }
  }
  guard kotlin_bin_dir is Some(dir) else {
    @log.error("无法获取到 kotlin 的 bin 目录")
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
) -> ProgramExeInfo? {
  if program.is_blank() || version.is_blank() {
    return None
  }
  let tool_dir = version_dir(Tool::Kotlin, version)
  let exists = @fs.exists(tool_dir)
  let kotlin_info = ProgramExeInfo(
    "kotlin",
    Kotlin::get_exe_path(version),
    version,
    envs={},
    exists,
    Tool::Kotlin,
    exists,
  )
  let prog_low = program.to_lower()
  if prog_low == "kotlin" {
    return Some(kotlin_info)
  } else if prog_low == "kotlinc" {
    // 直接构造 ProgramExeInfo
    let os = @os.get_os_name()
    let suffix = if os is Windows { ".bat" } else { "" }
    let kotlin_bin_dir = @fs_ext.get_parent_dir(kotlin_info.path)
    match kotlin_bin_dir {
      Some(dir) => {
        let tool_path = @fs_ext.join_path(dir, "\{prog_low}\{suffix}")
        let exists = @fs.exists(tool_path)
        return Some(ProgramExeInfo(
          prog_low,
          tool_path,
          version,
          envs={},
          exists,
          Tool::Kotlin,
          exists,
        ))
      }
      _ => ()
    }
  }
  None
}
