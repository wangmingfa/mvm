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
  if version_count == 3 {
    // 从缓存中获取
    let cache_file_content = read_cache_file_content(BUN_INDEX_CACHE_FILE)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = Bun::_get_proper_version(
        os, version, version_count, json,
      ) catch {
        _ => ""
      }
      if !target_version.is_blank() {
        return target_version
      }
    }
  }
  // 从远程获取版本索引
  let (res, data) = @http.get(BUN_INDEX_URL, headers={
    "User-Agent": "curl/8.7.1",
    "Accept": "application/vnd.github+json",
  })
  guard res.code is (200..<300) else {
    raise fail("无法获取到Bun版本信息：\{res.reason}")
  }
  let json = data.json()
  write_cache_file_content(BUN_INDEX_CACHE_FILE, json.stringify(indent=2))
  Bun::_get_proper_version(os, version, version_count, json)
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
  let versions : Array[(String, BunReleaseInfo)] = []
  for info in bunInfos {
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
      versions.push((ver.to_string(), info))
    }
  }
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
          guard versions.search_by(v => {
              if version_count == 3 {
                v.0 == version
              } else {
                v.0.has_prefix(version + ".")
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
    Aarch64 => "arm64"
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
  let asset_names = bunReleaseInfo.assets.map(v => v.name)
  if asset_names.all(v => !v.has_prefix(platform_name)) {
    let variables = {
      "version": () => version,
      "os.name": () => os.name.to_string(),
      "os.arch": () => os.arch.to_string(),
    }
    let mut msg = error_msg_tpl
    for key, value in variables {
      msg = msg.replace_all(old="{\{key}}", new=@utils.yellow(value()))
    }
    raise fail(msg)
  }
  version
}

///|
pub fn Bun::get_download_url(
  os_info : @os.OsInfo,
  version : String,
) -> String raise {
  let os_str = match os_info.name {
    MacOS => "darwin"
    Linux => "linux"
    Windows => "windows"
    name => raise fail("不支持的操作系统：\{name}")
  }
  let arch_str = match os_info.arch {
    Aarch64 => "arm64"
    X86_64 => "x64"
    X86 => "x64"
    arch => raise fail("不支持的架构：\{arch}")
  }
  let ext = match os_info.name {
    Windows => "zip"
    _ => "zip"
  }
  // Bun 的 tag 格式为 bun-v1.2.5
  let tag = if version.has_prefix("v") {
    "bun-\{version}"
  } else {
    "bun-v\{version}"
  }
  "\{BUN_RELEASE_URL}/\{tag}/bun-\{os_str}-\{arch_str}.\{ext}"
}

///|
pub fn Bun::get_exe_path(version : String) -> String {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Bun, version), "bun", suffix]
  .filter(v => !v.is_blank())
  .join("/")
}
