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
    version[3:].to_owned()
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

  if version_count == 3 {
    let cache_file_content = read_cache_file_content(GO_INDEX_CACHE_FILE)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = Go::_get_proper_version(
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
  let (res, data) = @http.get(GO_INDEX_URL)
  guard res.code is (200..<300) else {
    raise fail("无法获取到Go版本信息：\{res.reason}")
  }
  let json = data.json()
  write_cache_file_content(GO_INDEX_CACHE_FILE, json.stringify(indent=2))
  Go::_get_proper_version(os, version, version_count, json)
}

///|
fn Go::_get_proper_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(versions) else {
    raise fail("Go版本信息格式不对")
  }

  // 收集所有稳定版本
  let stable_versions : Array[(String, Json)] = []
  for item in versions {
    guard item is Object(map) else { continue }
    guard map.get("stable") is Some(stable_json) else { continue }
    guard stable_json.stringify() == "true" else { continue }
    guard map.get("version") is Some(String(ver)) else { continue }
    // 去除 "go" 前缀得到纯版本号（如 "go1.23.4" -> "1.23.4"）
    let clean_ver = if ver.has_prefix("go") { ver[3:].to_owned() } else { ver }
    stable_versions.push((clean_ver, item))
  }

  // 按版本号倒序排序
  stable_versions.sort_by((a, b) => {
    @utils.compare_version(b.0, a.0) catch {
      _ => 0
    }
  })
  guard stable_versions.length() > 0 else { raise fail("Go版本信息为空") }

  match version {
    "" | "latest" =>
      Go::_check_os_compatiable(
        os,
        stable_versions[0].0,
        stable_versions[0].1,
        error_msg_tpl="当前最新版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
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
            raise fail("找不到版本：\{version}")
          }
          Go::_check_os_compatiable(
            os,
            stable_versions[idx].0,
            stable_versions[idx].1,
            error_msg_tpl="版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
          )
        }
        _ => raise fail("无效的版本号：\{version}")
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
      name => raise fail("不支持的操作系统：\{name}")
    },
    match os.arch {
      Aarch64 => "arm64"
      X86_64 => "amd64"
      X86 => "386"
      arch => raise fail("不支持的架构：\{arch}")
    },
  ].join("-")
}

///|
fn Go::_check_os_compatiable(
  os : @os.OsInfo,
  version : String,
  version_json : Json,
  error_msg_tpl? : String = "版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
) -> String raise {
  guard version_json is Object(map) else {
    raise fail("版本 \{version} 的信息格式不对")
  }
  guard map.get("files") is Some(Array(files)) else {
    raise fail("版本 \{version} 缺少文件列表")
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
pub fn Go::get_download_url(
  os_info : @os.OsInfo,
  version : String,
) -> String raise {
  let version_release_key = Go::_get_version_release_key()
  let ext = match os_info.name {
    Windows => "zip"
    MacOS => "tar.gz"
    Linux => "tar.gz"
    name => raise fail("不支持的操作系统：\{name}")
  }
  "\{GO_RELEASE_URL}/go\{version}.\{version_release_key}.\{ext}"
}

///|
pub fn Go::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Go, version), "bin", "go\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}
