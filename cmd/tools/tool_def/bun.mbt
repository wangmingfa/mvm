///|
const BUN_RELEASE_URL = "https://github.com/oven-sh/bun/releases/download"

///|
const BUN_INDEX_URL = "https://api.github.com/repos/oven-sh/bun/releases"

///|
const BUN_INDEX_CACHE_FILE = "bun_releases.json"

///|
pub struct Bun {}

///|
test "Bun" {
  // 去除 Warning (struct_never_constructed) 警告
  let _ = Bun::{  }
}

///|
struct BunReleaseInfo {
  tag_name : String
  assets : Array[BunAssetInfo]
} derive(@json.FromJson)

///|
struct BunAssetInfo {
  name : String
} derive(@json.FromJson)

///|
pub async fn Bun::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  get_target_version_with_cache(
    BUN_INDEX_CACHE_FILE,
    BUN_INDEX_URL,
    "Bun",
    os,
    version,
    version_count,
    Bun::_get_proper_version,
    headers=@request.github_headers(),
  )
}

///|
fn Bun::_get_proper_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(arr) else { raise fail("Bun版本信息格式不对") }
  let bunInfos : Array[BunReleaseInfo] = arr.map(v => {
    @json.from_json(v) catch {
      _ => raise fail("解析Bun版本信息失败")
    }
  })
  guard bunInfos.length() > 0 else { raise fail("Bun版本信息为空") }
  // 提取纯版本号并过滤预发布版本
  let versions : Array[(String, BunReleaseInfo)] = bunInfos
    .map(info => {
      let tag = info.tag_name
      // Bun 的 tag 格式为 bun-v1.2.5 或 v1.2.5
      let ver = if tag.has_prefix("bun-") {
        tag["bun-".length():]
      } else if tag.has_prefix("v") {
        tag[1:]
      } else {
        tag
      }
      // 跳过预发布版本
      if !ver.contains("-canary") && !ver.contains("-debug") {
        return (ver.to_owned(), info)
      }
      return ("", info)
    })
    .filter(v => !v.0.is_blank())

  let all_versions = versions.map(v => v.0).join("、")
  @log.debug("所有版本: \{all_versions}")

  // 按版本号倒序排序
  versions.sort_by((a, b) => @utils.compare_version(b.0, a.0) catch { _ => 0 })
  guard versions.length() > 0 else { raise fail("Bun版本信息为空") }
  match version {
    "" | "latest" =>
      Bun::_check_os_compatiable(
        os,
        versions[0].0,
        versions[0].1,
        error_msg_tpl="当前最新版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
      )
    _ =>
      match version_count {
        1..=3 => {
          let find_version = if version.has_prefix("v") {
            version
          } else {
            "v\{version}"
          }
          guard versions.search_by(v => {
              if version_count == 3 {
                v.0 == find_version
              } else {
                v.0.has_prefix(find_version + ".")
              }
            })
            is Some(idx) else {
            raise fail("找不到版本：\{version}")
          }
          Bun::_check_os_compatiable(
            os,
            versions[idx].0,
            versions[idx].1,
            error_msg_tpl="版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
          )
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
fn Bun::_get_platform_asset_name() -> String raise {
  let os = @os.get_os_info()
  let os_str = match os.name {
    MacOS => "darwin"
    Linux => "linux"
    Windows => "windows"
    name => raise fail("不支持的操作系统：\{name}")
  }
  let arch_str = match os.arch {
    Aarch64 => "aarch64"
    X86_64 => "x64"
    X86 => "x64"
    arch => raise fail("不支持的架构：\{arch}")
  }
  "bun-\{os_str}-\{arch_str}"
}

///|
fn Bun::_check_os_compatiable(
  os : @os.OsInfo,
  version : String,
  bunReleaseInfo : BunReleaseInfo,
  error_msg_tpl? : String = "版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
) -> String raise {
  let platform_name = Bun::_get_platform_asset_name()
  @log.debug("平台名 \{platform_name}")

  let asset_names = bunReleaseInfo.assets.map(v => v.name)
  if asset_names.all(v => !v.has_prefix(platform_name)) {
    raise fail(format_os_compat_error(error_msg_tpl, version, os))
  }
  version
}

///|

///|
/// 获取 Bun 的下载信息（URL 和 headers）
pub fn Bun::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  let _ = os_info
  let platform_name = Bun::_get_platform_asset_name()
  let ext = "zip"
  // Bun 的 tag 格式为 bun-v1.2.5
  let tag = if version.has_prefix("v") {
    "bun-\{version}"
  } else {
    "bun-v\{version}"
  }
  let url = "\{BUN_RELEASE_URL}/\{tag}/\{platform_name}.\{ext}"
  { url, headers: {}, root_path_depth: 1 }
}

///|
/// 获取 Bun 的预期 SHA256 校验值
/// 从 GitHub Releases 的 SHA256SUMS.txt 获取
pub async fn Bun::get_expected_checksum(
  _os_info : @os.OsInfo,
  version : String,
) -> String? {
  // 构建归档文件名（与 get_download_info 一致）
  let platform_name_result = try? Bun::_get_platform_asset_name()
  guard platform_name_result is Ok(platform_name) else { return None }
  let archive_filename = "\{platform_name}.zip"

  // 构建 tag（与 get_download_info 一致）
  let tag = if version.has_prefix("v") {
    "bun-\{version}"
  } else {
    "bun-v\{version}"
  }
  // 保留原始 GitHub URL，作为代理失败时的回退
  let original_url = "\{BUN_RELEASE_URL}/\{tag}/SHASUMS256.txt"

  // 应用镜像/代理配置
  let (_, global_config) = get_global_config()
  let ctx = UrlReplaceContext::new(original_url, "bun", version, "", "")
  let proxied_url = apply_global_config(original_url, global_config, ctx)

  // 构建 URL 尝试列表：代理优先，GitHub 原链接兜底
  // 某些 GitHub 代理未实现 SHA256SUMS.txt 等辅助文件的代理，需要回退机制
  let urls = if proxied_url != original_url {
    [proxied_url, original_url]
  } else {
    [original_url]
  }
  // let headers = {
  //   "User-Agent": "curl/8.7.1",
  //   "Accept": "application/octet-stream",
  // }

  // 尝试从缓存读取
  let cache_file = "bun_shasums_\{version}.txt"
  let cached_content = read_cache_file_content(cache_file)
  let shasums_content = match cached_content {
    Some(content) => content
    None => {
      // 顺序尝试 URL 列表，首个成功即返回
      let result = @request.try_urls(urls, "Bun SHA256 校验文件")
      guard result is Some((_, content)) else { return None }
      write_cache_file_content(cache_file, content)
      content
    }
  }

  // 解析 SHA256SUMS.txt，查找匹配的文件名
  // 格式: <hash>  <filename> (两个空格分隔)
  _parse_bun_shasums(shasums_content, archive_filename)
}

///|
/// 解析 Bun SHA256SUMS.txt 文件内容
/// 格式: <hash>  <filename>
fn _parse_bun_shasums(content : String, filename : String) -> String? {
  let lines = content.split("\n")
  for line in lines {
    let line = line.trim().to_owned()
    if line.is_blank() {
      continue
    }
    let parts = line.split("  ").to_array()
    if parts.length() >= 2 {
      let hash = parts[0].trim().to_owned().to_lower()
      let name = parts[1].trim().to_owned()
      if name == filename {
        return Some(hash)
      }
    }
  }
  None
}

///|
pub fn Bun::get_exe_path(version : String) -> String raise {
  // let os = @os.get_os_name()
  // let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Bun, version), "bun"].filter(v => !v.is_blank()).join("/")
}
