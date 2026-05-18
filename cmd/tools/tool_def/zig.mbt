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
  get_target_version_with_cache(
    ZIG_INDEX_CACHE_FILE,
    ZIG_INDEX_URL,
    "Zig",
    os,
    version,
    version_count,
    Zig::_get_proper_version,
  )
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
    raise fail(format_os_compat_error(error_msg_tpl, version, os))
  }
  version
}

///|

///|
/// 获取 Zig 的下载信息（URL 和 headers）
pub fn Zig::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  let version_release_key = Zig::_get_version_release_key()
  let ext = match os_info.name {
    Windows => "zip"
    Linux => "tar.xz"
    MacOS => "tar.xz"
    name => raise fail("不支持的操作系统：\{name}")
  }
  let url = "\{ZIG_RELEASE_URL}/\{version}/zig-\{version_release_key}-\{version}.\{ext}"
  { url, headers: {}, root_path_depth: 1 }
}

///|
/// 获取 Zig 的预期 SHA256 校验值
/// 从缓存的 zig_index.json 中提取对应平台版本的 shasum 字段
pub async fn Zig::get_expected_checksum(
  os_info : @os.OsInfo,
  version : String,
) -> String? {
  // 构建平台键（如 "x86_64-macos"）
  let version_release_key = [
    match os_info.arch {
      Aarch64 => "aarch64"
      X86_64 => "x86_64"
      X86 => "x86"
      _ => return None
    },
    match os_info.name {
      Windows => "windows"
      MacOS => "macos"
      Linux => "linux"
      _ => return None
    },
  ].join("-")

  // 从缓存读取索引 JSON
  let cached_content = read_cache_file_content(ZIG_INDEX_CACHE_FILE)
  guard cached_content is Some(content) else {
    @log.warn("Zig 索引缓存不存在，无法获取校验值")
    return None
  }
  let json = @json.parse(content) catch {
    _ => {
      @log.warn("Zig 索引缓存格式错误，无法获取校验值")
      return None
    }
  }
  guard json is Object(map) else { return None }

  // 查找版本对应的 JSON 值
  guard map.get(version) is Some(version_json) else {
    @log.warn("Zig 版本 \{version} 不在索引中，无法获取校验值")
    return None
  }
  guard version_json is Object(version_map) else { return None }

  // 查找平台键对应的 shasum
  guard version_map.get(version_release_key) is Some(platform_json) else {
    @log.warn(
      "Zig 版本 \{version} 不包含 \{version_release_key} 平台信息，无法获取校验值",
    )
    return None
  }
  guard platform_json is Object(platform_map) else { return None }

  match platform_map.get("shasum") {
    Some(String(hash)) => Some(hash)
    _ => {
      @log.warn("Zig \{version}/\{version_release_key} 缺少 shasum 字段")
      None
    }
  }
}

///|
pub fn Zig::get_exe_path(version : String) -> String raise {
  // let os = @os.get_os_name()
  // let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Zig, version), "zig"].filter(v => !v.is_blank()).join("/")
}

///|
pub async fn Zig::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail("请指定 program 或 version")
  }
  let tool_dir = version_dir(Tool::Zig, version)
  let exists = @fs.exists(tool_dir)
  if program.to_lower() == "zig" {
    return ProgramExeInfo(
      "zig",
      Zig::get_exe_path(version),
      version,
      envs={},
      exists,
      Tool::Zig,
      exists,
    )
  }
  raise fail("找不到 \{program}@\{version} 的可执行文件信息")
}
