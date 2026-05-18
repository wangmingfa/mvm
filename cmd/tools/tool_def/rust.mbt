///|
/// Rust 官方发布源
const RUST_RELEASE_URL = "https://static.rust-lang.org/dist"

///|
/// Rust stable 通道 manifest URL
const RUST_STABLE_MANIFEST_URL = "https://static.rust-lang.org/dist/channel-rust-stable.toml"

///|
/// Rust nightly 通道 manifest URL
const RUST_NIGHTLY_MANIFEST_URL = "https://static.rust-lang.org/dist/channel-rust-nightly.toml"

///|
/// Rust beta 通道 manifest URL
const RUST_BETA_MANIFEST_URL = "https://static.rust-lang.org/dist/channel-rust-beta.toml"

///|
const RUST_INDEX_CACHE_FILE = "rust_stable_manifest.toml"

///|
struct Rust {}

///|
/// 存储 manifest 中提取的下载信息（URL + SHA256 hash）
/// 供 get_download_info 和 get_expected_checksum 同步读取
/// 格式: Some((url, hash)) 或 None
let rust_manifest_target_info : Ref[(String, String)?] = Ref(None)

///|
test "Rust" {
  let _ = Rust::{  }
}

///|
/// 构造 Rust 目标三元组（如 aarch64-apple-darwin）
fn _build_rust_target(os_info : @os.OsInfo) -> String raise {
  match os_info.name {
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
}

///|
pub async fn Rust::get_target_version(
  os : @os.OsInfo,
  version : String,
  _version_count : Int,
) -> String {
  match version {
    "" | "stable" | "lts" | "latest" =>
      Rust::_get_channel_version(
        os,
        "stable",
        RUST_STABLE_MANIFEST_URL,
        RUST_INDEX_CACHE_FILE,
      )
    "nightly" =>
      Rust::_get_channel_version(
        os,
        "nightly",
        RUST_NIGHTLY_MANIFEST_URL,
        "rust_nightly_manifest.toml",
      )
    "beta" =>
      Rust::_get_channel_version(
        os,
        "beta",
        RUST_BETA_MANIFEST_URL,
        "rust_beta_manifest.toml",
      )
    _ => {
      // 具体版本号，加 v 前缀；同时清空 manifest 缓存（指定版本时无 manifest 数据）
      rust_manifest_target_info.val = None
      let ver = if version.has_prefix("v") { version } else { "v\{version}" }
      ver
    }
  }
}

///|
/// 从 channel manifest 中提取版本号，并缓存下载 URL 和 SHA256 hash
async fn Rust::_get_channel_version(
  os : @os.OsInfo,
  channel : String,
  manifest_url : String,
  cache_file : String,
) -> String {
  let cached_content = read_cache_file_content(cache_file)
  let manifest_content = match cached_content {
    Some(content) => content
    None => {
      // 应用镜像配置
      let (_, global_config) = get_global_config()
      let ctx = UrlReplaceContext::new(
        manifest_url,
        "rust",
        "stable",
        os.name.to_string(),
        os.arch.to_string(),
      )
      let manifest_url = apply_global_config(manifest_url, global_config, ctx)

      let (res, data) = @http.get(
        manifest_url,
        headers=@request.merge_detault_headers(),
      )
      if !(res.code is (200..<300)) {
        raise fail(
          "无法获取 Rust \{channel} manifest（HTTP \{res.code} \{res.reason}，URL: \{manifest_url}）",
        )
      }
      let content = data.text()
      write_cache_file_content(cache_file, content)
      content
    }
  }
  // 从 TOML manifest 中提取 rust 版本号
  // 只查找 [pkg.rust] 段中的 version，避免误取 [pkg.cargo] 等段
  let version = _extract_rust_version(manifest_content)

  // 同时提取当前平台的下载 URL 和 SHA256 hash，供后续同步函数使用
  let target = _build_rust_target(os) catch { _ => "" }
  if !target.is_blank() {
    let url = _extract_rust_target_url(manifest_content, target)
    let hash = _extract_rust_target_hash(manifest_content, target)
    match (url, hash) {
      (Some(u), Some(h)) => rust_manifest_target_info.val = Some((u, h))
      _ => rust_manifest_target_info.val = None
    }
  }

  "v\{version}"
}

///|
/// 从 TOML manifest 文本中提取 rust 版本号
/// 只查找 [pkg.rust] 段中的 version 字段，避免误取 [pkg.cargo] 等段的版本号
/// 格式: [pkg.rust] version = "1.95.0 (hash date)"
fn _extract_rust_version(content : String) -> String raise {
  let lines = content.split("\n")
  let mut in_rust_section = false
  for line in lines {
    let trimmed = line.trim()
    // 进入 [pkg.rust] 段
    if trimmed == "[pkg.rust]" {
      in_rust_section = true
      continue
    }
    // 遇到新的段标记，退出当前段
    if in_rust_section && trimmed.has_prefix("[") && trimmed.has_suffix("]") {
      break
    }
    // 在 [pkg.rust] 段内查找 version 字段
    if in_rust_section && trimmed.has_prefix("version = \"") {
      let parts = trimmed.split("\"").to_array()
      if parts.length() >= 2 {
        let full_version = parts[1].to_owned()
        // 版本号格式: "1.95.0 (hash date)" 或 "1.95.0"
        // 提取纯版本号部分（空格前的部分）
        let space_parts = full_version.split(" ").to_array()
        return space_parts[0].to_owned()
      }
    }
  }
  raise fail("无法从 Rust manifest 中提取 [pkg.rust] 版本号")
}

///|
/// 从 TOML manifest 文本中提取指定 target 的下载 URL
/// 格式: [pkg.rust.target.aarch64-apple-darwin] url = "https://..."
fn _extract_rust_target_url(content : String, target : String) -> String? {
  let target_section = "[pkg.rust.target.\{target}]"
  let lines = content.split("\n")
  let mut in_target_section = false
  for line in lines {
    let trimmed = line.trim()
    if trimmed == target_section {
      in_target_section = true
      continue
    }
    // 遇到新的段标记，退出当前段
    if in_target_section && trimmed.has_prefix("[") && trimmed.has_suffix("]") {
      break
    }
    if in_target_section && trimmed.has_prefix("url = \"") {
      let parts = trimmed.split("\"").to_array()
      if parts.length() >= 2 {
        return Some(parts[1].to_owned())
      }
    }
  }
  None
}

///|
/// 从 TOML manifest 文本中提取指定 target 的 SHA256 hash
/// 格式: [pkg.rust.target.aarch64-apple-darwin] hash = "ec23ad2e..."
fn _extract_rust_target_hash(content : String, target : String) -> String? {
  let target_section = "[pkg.rust.target.\{target}]"
  let lines = content.split("\n")
  let mut in_target_section = false
  for line in lines {
    let trimmed = line.trim()
    if trimmed == target_section {
      in_target_section = true
      continue
    }
    // 遇到新的段标记，退出当前段
    if in_target_section && trimmed.has_prefix("[") && trimmed.has_suffix("]") {
      break
    }
    if in_target_section && trimmed.has_prefix("hash = \"") {
      let parts = trimmed.split("\"").to_array()
      if parts.length() >= 2 {
        return Some(parts[1].to_owned())
      }
    }
  }
  None
}

///|
/// 获取 Rust 的下载信息
/// 优先使用 manifest 中的 URL（包含正确的日期路径），无缓存时手动构造
pub fn Rust::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  // Rust URL 中版本号不带 v 前缀
  let ver = if version.has_prefix("v") {
    version.sub(start=1).to_owned()
  } else {
    version
  }
  // 构造目标三元组
  let target = _build_rust_target(os_info)

  // 优先使用 manifest 缓存中的 URL（包含日期路径，更可靠）
  let cached_info = rust_manifest_target_info.val
  match cached_info {
    Some((manifest_url, _)) =>
      { url: manifest_url, headers: {}, root_path_depth: 1 }
    None => {
      // 无缓存时手动构造 URL（适用于指定具体版本号的场景）
      let ext = if os_info.name is Windows { "zip" } else { "tar.gz" }
      let url = "\{RUST_RELEASE_URL}/rust-\{ver}-\{target}.\{ext}"
      { url, headers: {}, root_path_depth: 1 }
    }
  }
}

///|
/// 从 manifest 缓存中获取 SHA256 校验值
pub fn Rust::get_expected_checksum(
  _os_info : @os.OsInfo,
  _version : String,
) -> String? {
  match rust_manifest_target_info.val {
    Some((_, hash)) => Some(hash)
    None => None
  }
}

///|
pub fn Rust::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Rust, version), "bin", "rustc\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
/// 获取 Rust 内置工具（Cargo）的路径和版本
pub fn Rust::get_rust_builtin_tool_path_and_version(
  tool : Tool,
  rust_tool_exe : ProgramExeInfo,
) -> ProgramExeInfo? {
  let { path: rust_exe_path, .. } = rust_tool_exe

  let rust_bin_dir : String? = @fs_ext.get_parent_dir(rust_exe_path) catch {
    _ => {
      @log.error("无法获取到 rust 的 bin 目录")
      return None
    }
  }
  guard rust_bin_dir is Some(dir) else {
    @log.error("无法获取到 rust 的 bin 目录")
    return None
  }
  let rust_bin_dir = dir

  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  let tool_name = tool.to_string().to_lower()
  let tool_path = @fs_ext.join_path(rust_bin_dir, "\{tool_name}\{suffix}")

  Some(
    ProgramExeInfo(
      tool.to_str(),
      tool_path,
      rust_tool_exe.version,
      envs=rust_tool_exe.envs,
      true,
      rust_tool_exe.tool,
      rust_tool_exe.tool_exists,
    ),
  )
}

///|
pub async fn Rust::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail("请指定 program 或 version")
  }
  let tool_dir = version_dir(Tool::Rust, version)
  let exists = @fs.exists(tool_dir)
  let rustc_info = ProgramExeInfo(
    "rustc",
    Rust::get_exe_path(version),
    version,
    envs={},
    exists,
    Tool::Rust,
    exists,
  )
  let prog_low = program.to_lower()
  if prog_low == "rustc" {
    return rustc_info
  } else if prog_low == "cargo" {
    // 直接构造 ProgramExeInfo
    let os = @os.get_os_name()
    let suffix = if os is Windows { ".exe" } else { "" }
    let rust_bin_dir = @fs_ext.get_parent_dir(rustc_info.path)
    match rust_bin_dir {
      Some(dir) => {
        let tool_path = @fs_ext.join_path(dir, "\{prog_low}\{suffix}")
        let exists = @fs.exists(tool_path)
        return ProgramExeInfo(
          prog_low,
          tool_path,
          version,
          envs={},
          exists,
          Tool::Rust,
          exists,
        )
      }
      _ => ()
    }
  }
  raise fail("找不到 \{program}@\{version} 的可执行文件信息")
}
