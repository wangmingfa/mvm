///|
const BUN_RELEASE_URL = "https://github.com/oven-sh/bun/releases/download"

///|
/// Bun 版本列表来源（使用 mise-versions 避免 GitHub API 速率限制）
const BUN_VERSION_URL = "https://mise-versions.jdx.dev/tools/bun"

///|
const BUN_VERSIONS_CACHE_FILE = "bun_versions.json"

///|
pub struct Bun {}

///|
test "Bun" {
  // 去除 Warning (struct_never_constructed) 警告
  let _ = Bun::{  }
}

///|
pub async fn Bun::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  let _ = os
  // 尝试从缓存读取版本列表（仅当 version_count == 3 时使用缓存）
  if version_count == 3 {
    let cached = read_cache_file_content(BUN_VERSIONS_CACHE_FILE)
    if cached is Some(content) {
      let versions = Bun::_parse_cached_versions(content)
      if versions.length() > 0 {
        let result = Bun::_find_version(version, version_count, versions) catch {
          _ => ""
        }
        if !result.is_blank() {
          return result
        }
      }
    }
  }

  // 从 mise-versions 获取版本列表 HTML
  let (res, data) = @http.get(
    BUN_VERSION_URL,
    headers=@request.merge_detault_headers(),
  )
  guard res.code is (200..<300) else {
    raise fail(
      "无法获取到Bun版本信息（HTTP \{res.code} \{res.reason}，URL: \{BUN_VERSION_URL}）",
    )
  }
  let html = data.text()

  // 解析 HTML 中的版本信息
  let versions = Bun::_parse_versions_from_html(html)

  // 缓存版本列表（每行一个版本）
  write_cache_file_content(BUN_VERSIONS_CACHE_FILE, versions.join("\n"))

  // 从版本列表中查找目标版本
  Bun::_find_version(version, version_count, versions)
}

///|
async test "Bun::get_target_version" {
  let os = @os.get_os_info()
  let version = Bun::get_target_version(os, "0", 1)
  inspect(
    version,
    content=(
      #|v0.8.1
    ),
  )
}

///|
/// 从缓存中解析版本列表（每行一个版本）
fn Bun::_parse_cached_versions(content : String) -> Array[String] {
  content
  .split("\n")
  .map(v => v.trim().to_owned())
  .filter(v => !v.is_blank())
  .to_array()
}

///|
/// 从 mise-versions HTML 中解析版本列表
/// HTML 中包含两种 release URL 格式：
/// 1. <a> 标签：oven-sh/bun/releases/tag/vX.Y.Z（渲染的版本链接）
/// 2. Astro island props：oven-sh/bun/releases/tag/bun-vX.Y.Z（编码的数据）
/// 使用 releases/tag/ 作为分割点，同时处理 v 和 bun-v 两种前缀
fn Bun::_parse_versions_from_html(html : String) -> Array[String] raise {
  let separator =
    #|component-export="VersionsTable"
  let props_start_key =
    #|props="
  // 从props="xxxxx"中解析xxx
  guard html.split(separator).to_array().get(1) is Some(version_content) &&
    version_content.find(props_start_key) is Some(props_start_index) &&
    version_content[props_start_index + props_start_key.length():].find("\"")
    is Some(props_end_index) else {
    raise fail("无法解析到Bun的版本号")
  }
  // 替换转义字符
  let props_content = version_content[props_start_index +
    props_start_key.length():][:props_end_index]
    .replace_all(old="&quot;", new="\"")
    .replace_all(old="&gt;", new=">")

  guard (try? @json.parse(props_content)) is Ok(Object(json)) &&
    json.get("versions") is Some(Array(versions)) &&
    versions.get(1) is Some(Array(versions)) else {
    raise fail("无法解析到Bun的版本号")
  }

  let bun_versions : Array[String] = []

  for item in versions {
    guard item is Array(item_arr) &&
      item_arr.get(1) is Some(Object(version_obj)) else {
      continue
    }
    // version_obj的格式：
    //  {
    //   "version": [
    //     0,
    //     "0.0.0-9"
    //   ],
    //   "created_at": [
    //     0,
    //     "2021-09-14T20:23:51.000Z"
    //   ],
    //   "release_url": [
    //     0,
    //     null
    //   ],
    //   "prerelease": [
    //     0,
    //     false
    //   ]
    // }
    guard version_obj.get("version") is Some(Array(version_arr)) &&
      version_arr.get(1) is Some(String(version)) else {
      continue
    }
    bun_versions.push("v\{version}")
  }

  guard bun_versions.length() > 0 else { raise fail("Bun版本信息为空") }

  bun_versions.sort_by((a, b) => {
    @utils.compare_version(Bun::_strip_v_prefix(b), Bun::_strip_v_prefix(a)) catch {
      _ => 0
    }
  })

  let all_versions : String = bun_versions.join("、")
  @log.debug("所有Bun版本(\{bun_versions.length()}个): \{all_versions}")

  bun_versions
}

///|
/// 验证版本号是否为有效的 semver 格式
/// 仅允许数字和点号，且恰好有 2 个点号（表示 X.Y.Z 格式）
fn Bun::_is_valid_semver(version : String) -> Bool {
  let mut dot_count = 0
  for c in version {
    if c == '.' {
      dot_count += 1
    } else if !(c >= '0' && c <= '9') {
      break false
    }
  } nobreak {
    dot_count == 2
  }
}

///|
/// 去掉版本号的 "v" 前缀
fn Bun::_strip_v_prefix(version : String) -> String {
  if version.has_prefix("v") {
    let sv = version[1:]
    sv.to_owned()
  } else {
    version
  }
}

///|
/// 从排序后的版本列表中查找目标版本
fn Bun::_find_version(
  version : String,
  version_count : Int,
  versions : Array[String],
) -> String raise {
  guard versions.length() > 0 else { raise fail("Bun版本信息为空") }
  match version {
    "" | "latest" => versions[0]
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
                v == find_version
              } else {
                v.has_prefix(find_version + ".")
              }
            })
            is Some(idx) else {
            raise fail("找不到版本：\{version}")
          }
          versions[idx]
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
  [version_dir(Tool::Bun, version), "bun"].filter(v => !v.is_blank()).join("/")
}

///|
pub async fn Bun::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail("请指定 program 或 version")
  }
  let program_path = Bun::get_exe_path(version)
  let exists = @fs.exists(program_path)
  if program.to_lower() == "bun" {
    return ProgramExeInfo(
      "bun",
      program_path,
      version,
      version,
      envs={},
      exists,
      Tool::Bun,
      exists,
    )
  }
  raise fail("找不到 \{program}@\{version} 的可执行文件信息")
}
