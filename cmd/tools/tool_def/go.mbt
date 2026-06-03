///|
const GO_RELEASE_URL = "https://go.dev/dl"

///|
const GO_INDEX_URL = "https://go.dev/dl/?mode=json"

///|
const GO_INDEX_CACHE_FILE = "go_index.json"

///|
pub struct Go {}

///|
test "Go" {
  // 去除 Warning (struct_never_constructed) 警告
  let _ = Go::{  }
}

///|
pub async fn Go::get_target_version(
  os : @os.OsInfo,
  version : String,
  _version_count : Int,
) -> String {
  // 去除可能存在的 "go" 前缀（用户可能输入 go1.23 或 1.23）
  let version = if version.has_prefix("go") {
    version[2:].to_owned()
  } else {
    version
  }
  // Go 版本号不带 "v" 前缀，去除用户可能输入的 "v" 前缀
  let version = if version.has_prefix("v") {
    version[1:].to_owned()
  } else {
    version
  }
  // 重新计算版本号层级
  let version_count = lexmatch version with longest {
    "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" => 3
    "[[:digit:]]+\.[[:digit:]]+" => 2
    "[[:digit:]]+" => 1
    _ => 0
  }

  get_target_version_with_cache(
    GO_INDEX_CACHE_FILE,
    GO_INDEX_URL,
    "Go",
    os,
    version,
    version_count,
    Go::_get_proper_version,
  )
}

///|
fn Go::_get_proper_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(versions) else {
    raise fail(
      @i18n.t("error.version_info_format_wrong", args={ "tool": "Go" }),
    )
  }

  // 收集所有稳定版本
  let stable_versions : Array[(String, Json)] = []
  for item in versions {
    guard item is Object(map) else { continue }
    guard map.get("stable") is Some(stable_json) else { continue }
    guard stable_json.stringify() == "true" else { continue }
    guard map.get("version") is Some(String(ver)) else { continue }
    // 去除 "go" 前缀得到纯版本号（如 "go1.23.4" -> "1.23.4"）
    let clean_ver = if ver.has_prefix("go") { ver[2:].to_owned() } else { ver }
    stable_versions.push((clean_ver, item))
  }

  // 按版本号倒序排序
  stable_versions.sort_by((a, b) => {
    @utils.compare_version(b.0, a.0) catch {
      _ => 0
    }
  })
  guard stable_versions.length() > 0 else {
    raise fail(@i18n.t("error.version_info_empty", args={ "tool": "Go" }))
  }

  match version {
    "" | "latest" =>
      Go::_check_os_compatiable(
        os,
        stable_versions[0].0,
        stable_versions[0].1,
        error_msg_tpl=@i18n.t("error.version_os_arch_unsupported"),
      )
    _ =>
      match version_count {
        1..=3 => {
          guard stable_versions.search_by(v => {
              if version_count == 3 {
                v.0 == version
              } else {
                v.0.has_prefix(version + ".")
              }
            })
            is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          Go::_check_os_compatiable(
            os,
            stable_versions[idx].0,
            stable_versions[idx].1,
            error_msg_tpl=@i18n.t("error.version_os_arch_unsupported"),
          )
        }
        _ =>
          raise fail(
            @i18n.t("error.invalid_version_detail", args={ "version": version }),
          )
      }
  }
}

///|
fn Go::_get_version_release_key() -> String raise {
  let os = @os.get_os_info()
  [
    match os.name {
      Windows => "windows"
      MacOS => "darwin"
      Linux => "linux"
      name =>
        raise fail(
          @i18n.t("error.unsupported_os_detail", args={
            "name": name.to_string(),
          }),
        )
    },
    match os.arch {
      Aarch64 => "arm64"
      X86_64 => "amd64"
      X86 => "386"
      arch =>
        raise fail(
          @i18n.t("error.unsupported_arch", args={ "arch": arch.to_string() }),
        )
    },
  ].join("-")
}

///|
fn Go::_check_os_compatiable(
  os : @os.OsInfo,
  version : String,
  version_json : Json,
  error_msg_tpl? : String = @i18n.t("error.version_os_arch_unsupported"),
) -> String raise {
  guard version_json is Object(map) else {
    raise fail(
      @i18n.t("error.version_info_format_wrong", args={ "tool": "Go" }),
    )
  }
  guard map.get("files") is Some(Array(files)) else {
    raise fail(
      @i18n.t("error.version_info_format_wrong", args={ "tool": "Go" }),
    )
  }

  // 在 files 数组中查找匹配当前 OS 和架构的 archive 文件
  let expected_os = match os.name {
    Windows => "windows"
    MacOS => "darwin"
    Linux => "linux"
    _ => ""
  }
  let expected_arch = match os.arch {
    Aarch64 => "arm64"
    X86_64 => "amd64"
    X86 => "386"
    _ => ""
  }

  let found = for file in files {
    guard file is Object(file_map) else { continue }
    guard file_map.get("os") is Some(String(file_os)) else { continue }
    guard file_map.get("arch") is Some(String(file_arch)) else { continue }
    guard file_map.get("kind") is Some(String(kind)) else { continue }
    if kind != "archive" {
      continue
    }
    if file_os == expected_os && file_arch == expected_arch {
      break true
    }
  } nobreak {
    false
  }

  if !found {
    raise fail(format_os_compat_error(error_msg_tpl, version, os))
  }
  version
}

///|

///|
/// 获取 Go 的下载信息（URL 和 headers）
pub fn Go::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  let version_release_key = Go::_get_version_release_key()
  let ext = match os_info.name {
    Windows => "zip"
    MacOS => "tar.gz"
    Linux => "tar.gz"
    name =>
      raise fail(
        @i18n.t("error.unsupported_os_detail", args={ "name": name.to_string() }),
      )
  }
  let url = "\{GO_RELEASE_URL}/go\{version}.\{version_release_key}.\{ext}"
  { url, headers: {}, root_path_depth: 1 }
}

///|
/// 获取 Go 的预期 SHA256 校验值
/// 从缓存的 go_index.json 中提取对应平台归档文件的 sha256 字段
pub async fn Go::get_expected_checksum(
  os_info : @os.OsInfo,
  version : String,
) -> String? {
  // 构建预期的 os 和 arch 值（与 _check_os_compatiable 一致）
  let expected_os = match os_info.name {
    Windows => "windows"
    MacOS => "darwin"
    Linux => "linux"
    _ => return None
  }
  let expected_arch = match os_info.arch {
    Aarch64 => "arm64"
    X86_64 => "amd64"
    X86 => "386"
    _ => return None
  }

  // 从缓存读取索引 JSON
  let cached_content = read_cache_file_content(GO_INDEX_CACHE_FILE)
  guard cached_content is Some(content) else {
    @log.warn(@i18n.t("go.cache_not_exists"))
    return None
  }
  let json = @json.parse(content) catch {
    _ => {
      @log.warn(@i18n.t("go.cache_format_error"))
      return None
    }
  }
  guard json is Array(versions) else { return None }

  // 查找匹配版本（JSON 中版本带 "go" 前缀）
  let go_version = "go\{version}"
  let version_json = for item in versions {
    guard item is Object(map) else { continue }
    guard map.get("version") is Some(String(ver)) else { continue }
    if ver == go_version {
      break item
    }
  } nobreak {
    @log.warn(
      @i18n.t("go.version_not_in_index", args={ "version": go_version }),
    )
    return None
  }

  guard version_json is Object(map) else { return None }
  guard map.get("files") is Some(Array(files)) else { return None }

  // 在 files 数组中查找匹配的 archive 文件
  for file in files {
    guard file is Object(file_map) else { continue }
    guard file_map.get("os") is Some(String(file_os)) else { continue }
    guard file_map.get("arch") is Some(String(file_arch)) else { continue }
    guard file_map.get("kind") is Some(String(kind)) else { continue }
    if kind != "archive" {
      continue
    }
    if file_os != expected_os || file_arch != expected_arch {
      continue
    }
    // 找到匹配的文件，提取 sha256
    match file_map.get("sha256") {
      Some(String(hash)) => return Some(hash)
      _ => {
        @log.warn(
          @i18n.t("go.missing_sha256", args={
            "version": go_version,
            "platform": expected_os + "-" + expected_arch,
          }),
        )
        return None
      }
    }
  }

  @log.warn(
    @i18n.t("go.archive_not_found", args={
      "version": go_version,
      "platform": expected_os + "-" + expected_arch,
    }),
  )
  None
}

///|
pub fn Go::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Go, version), "bin", "go\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
pub async fn Go::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail(@i18n.t("error.specify_program_or_version"))
  }
  let tool_dir = version_dir(Tool::Go, version)
  let program_path = Go::get_exe_path(version)
  let exists = @fs.exists(program_path)
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  let prog_low = program.to_lower()
  if prog_low == "go" {
    return ProgramExeInfo(
      "go",
      program_path,
      version,
      version,
      envs={},
      exists,
      Tool::Go,
      exists,
    )
  } else if prog_low == "gofmt" {
    let gofmt_path = [tool_dir, "bin", "gofmt\{suffix}"]
      .filter(v => !v.is_blank())
      .join("/")
    let gofmt_exists = @fs.exists(gofmt_path)
    return ProgramExeInfo(
      "gofmt",
      gofmt_path,
      version,
      version,
      envs={},
      gofmt_exists,
      Tool::Go,
      exists,
    )
  }
  raise fail(
    @i18n.t("error.exe_info_not_found", args={
      "program": program,
      "version": version,
    }),
  )
}
