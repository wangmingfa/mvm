///|
/// Adoptium API 基础 URL（用于可用版本查询，仍可正常工作）
const JAVA_RELEASE_URL = "https://api.adoptium.net"

///|
/// Adoptium 可用版本信息 API
const JAVA_AVAILABLE_URL = "https://api.adoptium.net/v3/info/available_releases"

///|
/// Adoptium GitHub releases 仓库基础 URL（用于下载）
const JAVA_GITHUB_REPO_PREFIX = "https://github.com/adoptium/temurin"

///|
const JAVA_INDEX_CACHE_FILE = "java_index.json"

///|
struct Java {}

///|
test "Java" {
  let _ = Java::{  }
}

///|
/// 缓存版本信息（兼容旧缓存格式：{"tag_name":"jdk-22.0.2+9"}）
struct GithubReleaseInfo {
  tag_name : String
} derive(@json.FromJson)

///|
/// Adoptium API 版本信息（从 /v3/assets/latest/{major}/hotspot 获取）
/// 注意：semver 字段对 LTS 版本会附加后缀（如 "25.0.3+9.0.LTS"），不能直接用于构造下载链接
/// 使用 major/minor/security/build 字段构造干净版本号（如 "25.0.3+9"）
struct AdoptiumVersion {
  major : Int
  minor : Int
  security : Int
  build : Int
} derive(@json.FromJson)

///|
/// Adoptium API 资产信息
struct AdoptiumAsset {
  version : AdoptiumVersion
} derive(@json.FromJson)

///|
/// Adoptium 可用版本信息
struct JavaAvailableReleases {
  // 所有可用版本列表
  available_releases : Array[Int]
  // 可用的 LTS 版本列表
  available_lts_releases : Array[Int]
  // 最新的 LTS 版本
  most_recent_lts : Int
  // 最新的可用版本（包括非 LTS）
  most_recent_feature_release : Int
} derive(@json.FromJson)

///|
pub async fn Java::get_target_version(
  _os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  match version {
    // 默认/lts：安装最新 LTS 版本
    "" | "lts" => {
      let major = Java::_get_lts_major_version()
      @log.info("最新的LTS主版本 \{major}")
      Java::_resolve_latest_patch_version(major.to_string())
    }
    // latest：安装最新版本（包括非 LTS）
    "latest" => {
      let major = Java::_get_latest_major_version()
      Java::_resolve_latest_patch_version(major.to_string())
    }
    _ =>
      match version_count {
        // 仅主版本号，如 "21"
        1 => {
          let major = @string.parse_int(version) catch {
            _ => raise fail("无效的版本号：\{version}")
          }
          Java::_verify_major_version_available(major)
          Java::_resolve_latest_patch_version(version)
        }
        // 主版本号+次版本号 或 完整版本号，如 "21.0" 或 "21.0.11"
        // 均提取主版本号，从 GitHub 获取该主版本的最新版本
        2 | 3 => {
          let parts = version.split(".").collect()
          let major = parts[0].to_owned()
          let major_int = @string.parse_int(major) catch {
            _ => raise fail("无效的版本号：\{version}")
          }
          Java::_verify_major_version_available(major_int)
          Java::_resolve_latest_patch_version(major)
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
async test "get_target_version empty version" {
  let os = @os.get_os_info()
  inspect(
    Java::get_target_version(os, "", 0),
    content=(
      #|25.0.3+9
    ),
  )
}

///|
/// 获取最新的 LTS 主版本号
async fn Java::_get_lts_major_version() -> Int {
  let releases = Java::_fetch_available_releases()
  releases.most_recent_lts
}

///|
/// 获取最新的主版本号（包括非 LTS）
async fn Java::_get_latest_major_version() -> Int {
  let releases = Java::_fetch_available_releases()
  releases.most_recent_feature_release
}

///|
/// 从 Adoptium API 获取可用版本信息（带缓存）
async fn Java::_fetch_available_releases() -> JavaAvailableReleases {
  let cached_content = read_cache_file_content(JAVA_INDEX_CACHE_FILE)
  let content = match cached_content {
    Some(content) => content
    None => {
      // 应用镜像配置
      let (_, global_config) = get_global_config()
      let ctx = UrlReplaceContext::new(
        JAVA_AVAILABLE_URL,
        "java",
        "latest",
        "",
        "",
      )
      let url = apply_global_config(JAVA_AVAILABLE_URL, global_config, ctx)

      let (res, data) = @http.get(url, headers=@request.merge_detault_headers())
      if !(res.code is (200..<300)) {
        raise fail(
          "无法获取 Java 可用版本信息（HTTP \{res.code} \{res.reason}，URL: \{url}）",
        )
      }
      let content = data.text()
      write_cache_file_content(JAVA_INDEX_CACHE_FILE, content)
      content
    }
  }
  let json = @json.parse(content) catch {
    e => raise fail("解析 Java 版本信息失败：\{e}")
  }
  @json.from_json(json) catch {
    e => raise fail("解析 Java 版本信息失败：\{e}")
  }
}

///|
/// 验证主版本号是否可用
async fn Java::_verify_major_version_available(major : Int) -> Unit {
  let releases = Java::_fetch_available_releases()
  if !releases.available_releases.contains(major) &&
    !releases.available_lts_releases.contains(major) {
    raise fail("找不到版本：\{major}")
  }
}

///|
/// 从 Adoptium API 获取指定主版本的最新完整版本号（含 build 号）
/// 使用 /v3/assets/latest/{major}/hotspot 端点，无需 GitHub API，无速率限制
/// 从 major/minor/security/build 字段构造版本号，避免 LTS 版本 semver 的 ".0.LTS" 后缀
/// 例如：major_version="25" → 返回 "25.0.3+9"（而非 semver 的 "25.0.3+9.0.LTS"）
async fn Java::_resolve_latest_patch_version(major_version : String) -> String {
  // 使用缓存避免频繁请求
  let cache_file = "java_github_\{major_version}.json"
  let cached_content = read_cache_file_content(cache_file)
  match cached_content {
    Some(content) => {
      // 从缓存中解析版本号（兼容旧缓存格式：{"tag_name":"jdk-22.0.2+9"}）
      let json = @json.parse(content) catch {
        e =>
          raise fail("解析 Java \{major_version} 版本缓存失败：\{e}")
      }
      let release : GithubReleaseInfo = @json.from_json(json) catch {
        e =>
          raise fail("解析 Java \{major_version} 版本缓存失败：\{e}")
      }
      let tag = release.tag_name
      guard tag.has_prefix("jdk-") else {
        raise fail("无法从缓存 tag \{tag} 解析 Java 版本号")
      }
      tag["jdk-".length():].to_owned()
    }
    None => {
      // 使用 Adoptium 官方 API 获取最新版本号（无速率限制）
      let adoptium_url = "\{JAVA_RELEASE_URL}/v3/assets/latest/\{major_version}/hotspot"
      // 应用镜像配置（java_mirror 会替换 JAVA_RELEASE_URL）
      let (_, global_config) = get_global_config()
      let ctx = UrlReplaceContext::new(
        adoptium_url, "java", major_version, "", "",
      )
      let url = apply_global_config(adoptium_url, global_config, ctx)

      @log.info("获取Java版本的url \{url}")
      let (res, data) = @http.get(url, headers=@request.merge_detault_headers())
      if !(res.code is (200..<300)) {
        raise fail(
          "无法获取 Java \{major_version} 的版本信息（HTTP \{res.code}，URL: \{url}）",
        )
      }
      let content = data.text()

      // 解析 Adoptium API 返回的资产列表
      let json = @json.parse(content) catch {
        e =>
          raise fail("解析 Java \{major_version} 版本信息失败：\{e}")
      }
      let assets : Array[AdoptiumAsset] = @json.from_json(json) catch {
        e =>
          raise fail("解析 Java \{major_version} 版本信息失败：\{e}")
      }
      guard assets.length() > 0 else {
        raise fail(
          "无法获取 Java \{major_version} 的版本信息：API 返回空列表",
        )
      }
      // 从结构化字段构造干净版本号（避免 LTS 版本 semver 中的 ".0.LTS" 后缀）
      // 例如：major=25, minor=0, security=3, build=9 → "25.0.3+9"
      let v = assets[0].version
      let clean_version = "\{v.major}.\{v.minor}.\{v.security}+\{v.build}"
      // 缓存版本号（兼容旧缓存格式：{"tag_name":"jdk-25.0.3+9"})
      write_cache_file_content(
        cache_file,
        "{\"tag_name\":\"jdk-\{clean_version}\"}",
      )
      clean_version
    }
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
/// 使用 Adoptium GitHub releases 直接下载 URL
/// 需要版本号包含 build 号（如 "25.0.3+9"）
/// 代理/镜像由 install.mbt 在异步上下文中统一应用
pub fn Java::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  // 版本号必须包含 build 号（格式如 "25.0.3+9"）
  guard version.contains("+") else {
    raise fail(
      "Java 版本号 \{version} 缺少 build 号（需要格式如 25.0.3+9），无法构造下载链接",
    )
  }
  // 解析版本号：25.0.3+9 → version_without_build=25.0.3, build=9, major=25
  let plus_parts = version.split("+").collect()
  let version_without_build = plus_parts[0].to_owned()
  let build = plus_parts[1].to_owned()
  let major_parts = version_without_build.split(".").collect()
  let major = major_parts[0].to_owned()

  let arch = Java::_get_arch(os_info)
  let os_name = Java::_get_os_name(os_info)
  let ext = match os_info.name {
    Windows => "zip"
    _ => "tar.gz"
  }

  // GitHub tag（URL-encoded）：jdk-25.0.3%2B9
  let tag = "jdk-\{version_without_build}%2B\{build}"
  // Asset 文件名：OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.3_9.tar.gz
  let asset_name = "OpenJDK\{major}U-jdk_\{arch}_\{os_name}_hotspot_\{version_without_build}_\{build}.\{ext}"

  let url = "\{JAVA_GITHUB_REPO_PREFIX}\{major}-binaries/releases/download/\{tag}/\{asset_name}"
  // root_path_depth=1: 剥离 jdk-{version}/ 外层目录
  // macOS 安装后结构为 Contents/Home/bin/java（.app bundle），get_exe_path 会适配
  // Linux/Windows 安装后结构为 bin/java
  { url, headers: {}, root_path_depth: 1U }
}

///|
/// Java 校验值获取
/// 初期实现返回 None，后续可从 GitHub release 的 .sha256.txt 文件提取
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
  // macOS JDK 使用 .app bundle 结构，实际可执行文件在 Contents/Home/bin/ 下
  let bin_prefix = if os is MacOS { "Contents/Home/bin" } else { "bin" }
  [version_dir(Tool::Java, version), bin_prefix, "java\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
/// 获取 Java 内置工具（javac、jar）的路径和版本
pub fn Java::get_java_builtin_tool_path_and_version(
  tool : Tool,
  java_tool_exe : ProgramExeInfo,
) -> ProgramExeInfo? {
  let { path: java_exe_path, .. } = java_tool_exe
  let java_bin_dir : String? = @fs_ext.get_parent_dir(java_exe_path) catch {
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
    ProgramExeInfo(
      tool.to_str(),
      tool_path,
      java_tool_exe.version,
      envs=java_tool_exe.envs,
      true,
      java_tool_exe.tool,
      java_tool_exe.tool_exists,
    ),
  )
}

///|
pub async fn Java::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail("请指定 program 或 version")
  }
  let program_path = Java::get_exe_path(version)
  let exists = @fs.exists(program_path)
  let java_info = ProgramExeInfo(
    "java",
    program_path,
    version,
    envs={},
    exists,
    Tool::Java,
    exists,
  )
  let prog_low = program.to_lower()
  if prog_low == "java" {
    return java_info
  } else if prog_low == "javac" || prog_low == "jar" {
    // 直接构造 ProgramExeInfo，不用 Tool 枚举
    let os = @os.get_os_name()
    let suffix = if os is Windows { ".exe" } else { "" }
    let java_bin_dir = @fs_ext.get_parent_dir(java_info.path)
    match java_bin_dir {
      Some(dir) => {
        let tool_path = @fs_ext.join_path(dir, "\{prog_low}\{suffix}")
        let tool_exists = @fs.exists(tool_path)
        return ProgramExeInfo(
          prog_low,
          tool_path,
          version,
          envs={},
          tool_exists,
          Tool::Java,
          exists,
        )
      }
      _ => ()
    }
  }
  raise fail("找不到 \{program}@\{version} 的可执行文件信息")
}
