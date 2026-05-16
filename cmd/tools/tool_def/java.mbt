///| Java 镜像替换的基础 URL
const JAVA_RELEASE_URL = "https://api.adoptium.net"

///| Adoptium (Eclipse Temurin) API
const JAVA_AVAILABLE_URL = "https://api.adoptium.net/v3/info/available_releases"

///| Adoptium 直接下载 URL 模板（会重定向到实际文件）
const JAVA_BINARY_URL = "https://api.adoptium.net/v3/binary/latest"

///|
const JAVA_INDEX_CACHE_FILE = "java_index.json"

///|
struct Java {}

///|
test "Java" {
  let _ = Java::{  }
}

///|
/// Adoptium 可用版本信息
struct JavaAvailableReleases {
  // 可用的 LTS 版本列表
  available_lts_releases : Array[Int]
  // 最新的 LTS 版本
  most_recent_lts : Int
  // 最新的可用版本（包括非 LTS）
  most_recent_feature_release : Int
  // 所有可用版本列表
  available_releases : Array[Int]
} derive(@json.FromJson)

///|
pub async fn Java::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  let cached_content = read_cache_file_content(JAVA_INDEX_CACHE_FILE)
  let content = match cached_content {
    Some(content) => content
    None => {
      // 应用镜像配置
      let (_, global_config) = get_global_config()
      let ctx = UrlReplaceContext::new(JAVA_AVAILABLE_URL, "java", "latest", os.name.to_string(), os.arch.to_string())
      let url = apply_global_config(JAVA_AVAILABLE_URL, global_config, ctx)

      let (res, data) = @http.get(
        url,
        headers=@request.merge_detault_headers(),
      )
      if !(res.code is (200..<300)) {
        raise fail("无法获取 Java 可用版本信息（HTTP \{res.code} \{res.reason}，URL: \{url}）")
      }
      let content = data.text()
      write_cache_file_content(JAVA_INDEX_CACHE_FILE, content)
      content
    }
  }
  let json = @json.parse(content) catch {
    e => raise fail("解析 Java 版本信息失败：\{e}")
  }
  let releases : JavaAvailableReleases = @json.from_json(json) catch {
    e => raise fail("解析 Java 版本信息失败：\{e}")
  }
  match version {
    "" | "lts" => {
      let lts_version = releases.most_recent_lts.to_string()
      Java::_resolve_latest_patch_version(os, lts_version)
    }
    "latest" => {
      let latest_version = releases.most_recent_feature_release.to_string()
      Java::_resolve_latest_patch_version(os, latest_version)
    }
    _ => {
      match version_count {
        1 => {
          let major = @string.parse_int(version) catch {
            _ => raise fail("无效的版本号：\{version}")
          }
          if !releases.available_releases.contains(major) &&
            !releases.available_lts_releases.contains(major) {
            raise fail("找不到版本：\{version}")
          }
          Java::_resolve_latest_patch_version(os, version)
        }
        2 | 3 => version
        _ => raise fail("无效的版本号：\{version}")
      }
    }
  }
}

///|
/// 从 Adoptium API 获取指定主版本的最新补丁版本号
async fn Java::_resolve_latest_patch_version(
  os : @os.OsInfo,
  major_version : String,
) -> String {
  // 应用镜像配置
  let (_, global_config) = get_global_config()
  let ctx = UrlReplaceContext::new(JAVA_AVAILABLE_URL, "java", major_version, os.name.to_string(), os.arch.to_string())

  // 使用 Adoptium assets API 获取最新版本号
  let assets_url = "https://api.adoptium.net/v3/assets/latest/\{major_version}/hotspot/architecture/\{Java::_get_arch(os)}/os/\{Java::_get_os_name(os)}/image_type/jdk"
  let assets_url = apply_global_config(assets_url, global_config, ctx)

  let (res, data) = @http.get(
    assets_url,
    headers=@request.merge_detault_headers(),
  )
  if !(res.code is (200..<300)) {
    // 如果无法获取具体版本号，直接使用主版本号
    @log.warn("无法获取 Java \{major_version} 的具体版本号（HTTP \{res.code} \{res.reason}，URL: \{assets_url}），将使用主版本号")
    return major_version
  }
  let content = data.text()
  let json = @json.parse(content) catch {
    _ => return major_version
  }
  // Adoptium API 返回数组，提取版本号
  guard json is Array(arr) else { return major_version }
  guard arr.length() > 0 else { return major_version }
  let first = arr[0]
  guard first is Object(map) else { return major_version }
  guard map.get("release") is Some(Object(release_map)) else {
    return major_version
  }
  match release_map.get("semver") {
    Some(String(semver)) => semver
    _ => major_version
  }
}

///|
fn Java::_get_arch(os : @os.OsInfo) -> String {
  match os.arch {
    X86_64 => "x64"
    Aarch64 => "aarch64"
    X86 => "x32"
    _ => "x64"
  }
}

///|
fn Java::_get_os_name(os : @os.OsInfo) -> String {
  match os.name {
    MacOS => "mac"
    Linux => "linux"
    Windows => "windows"
    _ => "linux"
  }
}

///|
/// 获取 Java 的下载信息
/// 使用 Adoptium 直接下载 URL（会重定向到实际文件）
/// 镜像/代理替换在下载流程中处理
pub fn Java::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo {
  // 解析主版本号（取第一个 "." 之前的部分）
  let parts = version.split(".").collect()
  let major = parts[0].to_owned()
  let arch = Java::_get_arch(os_info)
  let os_name = Java::_get_os_name(os_info)
  let image_type = "jdk"
  // Adoptium 直接二进制下载 URL（会 302 重定向到 GitHub release）
  let url = "\{JAVA_BINARY_URL}/\{major}/\{os_name}/\{arch}/\{image_type}/hotspot/eclipse"
  { url, headers: {}, root_path_depth: 1 }
}

///|
/// Java 校验值获取
/// 初期实现返回 None，后续可从 Adoptium release assets 提取
pub fn Java::get_expected_checksum(
  _os_info : @os.OsInfo,
  _version : String,
) -> String? {
  None
}

///|
pub fn Java::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Java, version), "bin", "java\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
/// 获取 Java 内置工具（javac、jar）的路径和版本
pub fn Java::get_java_builtin_tool_path_and_version(
  tool : Tool,
  java_tool_exe : ToolExe,
) -> ToolExe? {
  let { path: java_exe_path, .. } = java_tool_exe

  let java_bin_dir : String? = try {
    @fs_ext.get_parent_dir(java_exe_path)
  } catch {
    _ => {
      @log.error("无法获取到 java 的 bin 目录")
      return None
    }
  }
  guard java_bin_dir is Some(dir) else {
    @log.error("无法获取到 java 的 bin 目录")
    return None
  }
  let java_bin_dir = dir

  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  let tool_name = tool.to_string().to_lower()
  let tool_path = @fs_ext.join_path(java_bin_dir, "\{tool_name}\{suffix}")

  Some(
    ToolExe::new_node_builtin_tool(
      tool,
      java_tool_exe,
      tool_path,
      java_tool_exe.version,
    ),
  )
}