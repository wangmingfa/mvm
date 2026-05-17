///|
/// Deno GitHub 发布源
const DENO_RELEASE_URL = "https://github.com/denoland/deno/releases/download"

///|
/// Deno GitHub releases API
const DENO_INDEX_URL = "https://api.github.com/repos/denoland/deno/tags?per_page=100"

///|
const DENO_INDEX_CACHE_FILE = "deno_index.json"

///|
struct Deno {}

///|
test "Deno" {
  let _ = Deno::{  }
}

///|
struct DenoReleaseInfo {
  name : String
} derive(@json.FromJson)

///|
pub async fn Deno::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  get_target_version_with_cache(
    DENO_INDEX_CACHE_FILE,
    DENO_INDEX_URL,
    "Deno",
    os,
    version,
    version_count,
    Deno::_get_proper_version,
    headers=@request.github_headers(),
  )
}

///|
fn Deno::_get_proper_version(
  _os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(arr) else { raise fail("Deno版本信息格式不对") }
  let infos : Array[DenoReleaseInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e => raise fail("解析Deno版本信息失败，原因：\{e}")
    }
  })
  // 过滤出有效版本号（排除 nightly 等）
  let valid_versions = infos.filter(fn(v) {
    let name = v.name
    // 只保留以 v 开头后跟数字的标签（如 v2.0.0, v1.40.0）
    name.has_prefix("v") &&
    name.length() > 1 &&
    name[1] >= '0' &&
    name[1] <= '9'
  })
  guard valid_versions.length() > 0 else {
    raise fail("Deno版本信息为空")
  }
  // 按版本号倒序排序
  valid_versions.sort_by((a, b) => {
    @utils.compare_version(b.name, a.name) catch {
      _ => 0
    }
  })
  match version {
    "" | "lts" | "latest" =>
      // 取最新版本
      valid_versions[0].name
    _ =>
      match version_count {
        1 | 2 | 3 => {
          let search_version = if version.has_prefix("v") {
            version
          } else {
            "v\{version}"
          }
          if version_count == 3 {
            // 精确匹配
            guard valid_versions.search_by(fn(v) { v.name == search_version })
              is Some(idx) else {
              raise fail("找不到版本：\{version}")
            }
            valid_versions[idx].name
          } else {
            // 前缀匹配
            guard valid_versions.search_by(fn(v) {
                v.name.has_prefix(search_version + ".")
              })
              is Some(idx) else {
              raise fail("找不到版本：\{version}")
            }
            valid_versions[idx].name
          }
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
/// 获取 Deno 的下载信息
pub fn Deno::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  // Deno version tag 带有 v 前缀
  let ver = if version.has_prefix("v") { version } else { "v\{version}" }
  // 构造目标三元组
  let target = match os_info.name {
    MacOS =>
      match os_info.arch {
        Aarch64 => "aarch64-apple-darwin"
        X86_64 => "x86_64-apple-darwin"
        arch => raise fail("不支持的架构：\{arch}")
      }
    Linux =>
      match os_info.arch {
        X86_64 => "x86_64-unknown-linux-gnu"
        Aarch64 => "aarch64-unknown-linux-gnu"
        arch => raise fail("不支持的架构：\{arch}")
      }
    Windows =>
      match os_info.arch {
        X86_64 => "x86_64-pc-windows-msvc"
        Aarch64 => "aarch64-pc-windows-msvc"
        arch => raise fail("不支持的架构：\{arch}")
      }
    name => raise fail("不支持的操作系统：\{name}")
  }
  let url = "\{DENO_RELEASE_URL}/\{ver}/deno-\{target}.zip"
  // Deno 是单一二进制文件，压缩包内无子目录
  { url, headers: {}, root_path_depth: 0 }
}

///|
/// Deno 无官方 SHA256 校验文件
pub fn Deno::get_expected_checksum(
  _os_info : @os.OsInfo,
  _version : String,
) -> String? {
  None
}

///|
/// Deno 是单一二进制文件，无 bin 子目录
pub fn Deno::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Deno, version), "deno\{suffix}"].join("/")
}
