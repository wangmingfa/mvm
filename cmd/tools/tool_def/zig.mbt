///|
const ZIG_RELEASE_URL = "https://ziglang.org/download"

///|
const ZIG_INDEX_URL = "https://ziglang.org/download/index.json"

///|
const ZIG_INDEX_CACHE_FILE = "zig_index.json"

///|
pub struct Zig {}

///|
test "Zig" {
  // 去除 Warning (struct_never_constructed) 警告
  let _ = Zig::{  }
}

///|
pub async fn Zig::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  if version_count == 3 {
    // 从缓存中获取
    let cache_file_content = read_cache_file_content(ZIG_INDEX_CACHE_FILE)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = Zig::_get_proper_version(
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
  let (res, data) = @http.get(ZIG_INDEX_URL)
  guard res.code is (200..<300) else {
    raise fail("无法获取到Zig版本信息：\{res.reason}")
  }
  let json = data.json()
  write_cache_file_content(ZIG_INDEX_CACHE_FILE, json.stringify(indent=2))
  Zig::_get_proper_version(os, version, version_count, json)
}

///|
fn Zig::_get_proper_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Object(map) else { raise fail("Zig版本信息格式不对") }
  // 收集所有稳定版本及其 JSON 值（跳过 master 和 dev 版本）
  let versions : Array[(String, Json)] = []
  for key, value in map {
    if key != "master" && !key.has_suffix("-dev") {
      versions.push((key, value))
    }
  }
  // 按版本号倒序排序
  versions.sort_by((a, b) => @utils.compare_version(b.0, a.0) catch { _ => 0 })
  guard versions.length() > 0 else { raise fail("Zig版本信息为空") }
  match version {
    "" | "latest" =>
      Zig::_check_os_compatiable(
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
          Zig::_check_os_compatiable(
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
fn Zig::_get_version_release_key() -> String raise {
  let os = @os.get_os_info()
  [
    match os.arch {
      Aarch64 => "aarch64"
      X86_64 => "x86_64"
      X86 => "x86"
      arch => raise fail("不支持的架构：\{arch}")
    },
    match os.name {
      Windows => "windows"
      MacOS => "macos"
      Linux => "linux"
      name => raise fail("不支持的操作系统：\{name}")
    },
  ].join("-")
}

///|
fn Zig::_check_os_compatiable(
  os : @os.OsInfo,
  version : String,
  version_json : Json,
  error_msg_tpl? : String = "版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
) -> String raise {
  let version_release_key = Zig::_get_version_release_key()
  guard version_json is Object(map) else {
    raise fail("版本 \{version} 的信息格式不对")
  }
  @log.debug("检查兼容性 \{version_release_key}")
  if !map.contains(version_release_key) {
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
pub fn Zig::get_download_url(
  os_info : @os.OsInfo,
  version : String,
) -> String raise {
  let version_release_key = Zig::_get_version_release_key()
  let ext = match os_info.name {
    Windows => "zip"
    Linux => "tar.xz"
    MacOS => "tar.xz"
    name => raise fail("不支持的操作系统：\{name}")
  }
  "\{ZIG_RELEASE_URL}/\{version}/zig-\{version_release_key}-\{version}.\{ext}"
}

///|
pub fn Zig::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Zig, version), "zig", suffix]
  .filter(v => !v.is_blank())
  .join("/")
}
