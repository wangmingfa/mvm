///|
/// Python 官方发布源
const PYTHON_RELEASE_URL = "https://www.python.org/ftp/python"

///|
/// Python standalone 预编译包（astral-sh/python-build-standalone）
const PYTHON_STANDALONE_REPO = "astral-sh/python-build-standalone"

///|
const PYTHON_STANDALONE_CACHE = "python_standalone_tag.txt"

///|
const PYTHON_INDEX_URL = "https://endoflife.date/api/python.json"

///|
const PYTHON_INDEX_CACHE_FILE = "python_index.json"

///|
struct Python {}

///|
test "Python" {
  let _ = Python::{  }
}

///|
struct PythonVersionInfo {
  // 版本周期，如 "3.12"
  cycle : String
  // 该周期下的最新版本，如 "3.12.4"
  latest : String
} derive(@json.FromJson)

///|
pub async fn Python::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  get_target_version_with_cache(
    PYTHON_INDEX_CACHE_FILE,
    PYTHON_INDEX_URL,
    "Python",
    os,
    version,
    version_count,
    Python::_get_proper_version,
  )
}

///|
fn Python::_get_proper_version(
  _os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
  guard json is Array(arr) else {
    raise fail(
      @i18n.t("error.version_info_format_wrong", args={ "tool": "Python" }),
    )
  }
  let infos : Array[PythonVersionInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e =>
        raise fail(
          @i18n.t("error.parse_version_info_failed", args={
            "tool": "Python",
            "reason": e.to_string(),
          }),
        )
    }
  })
  guard infos.length() > 0 else {
    raise fail(@i18n.t("error.version_info_empty", args={ "tool": "Python" }))
  }
  // 按版本号倒序排序
  infos.sort_by((a, b) => {
    @utils.compare_version(b.latest, a.latest) catch {
      _ => 0
    }
  })
  match version {
    "" | "lts" | "latest" => {
      // Python 没有 LTS 概念，lts 和 latest 都取最新版本
      let v = infos[0].latest
      "v\{v}"
    }
    _ =>
      match version_count {
        // 仅主版本号，如 "2" 或 "3"
        1 => {
          let ver = if version.has_prefix("v") {
            version.sub(start=1).to_owned()
          } else {
            version
          }
          // endoflife.date API 的 cycle 为 major.minor 格式
          // 查找以该主版本号开头的最新 cycle
          guard infos.search_by(fn(v) { v.cycle.has_prefix("\{ver}.") })
            is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          "v\{infos[idx].latest}"
        }
        // 主版本号+次版本号，如 "3.12"
        2 => {
          let search_version = if version.has_prefix("v") {
            version
          } else {
            "v\{version}"
          }
          // 去掉 v 前缀用于匹配 cycle
          let cycle = search_version.sub(start=1).to_owned()
          guard infos.search_by(fn(v) { v.cycle == cycle }) is Some(idx) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          "v\{infos[idx].latest}"
        }
        // 完整版本号，如 "3.12.4"
        3 => {
          let ver = if version.has_prefix("v") {
            version.sub(start=1).to_owned()
          } else {
            version
          }
          // endoflife.date API 只有每个 cycle 的最新版本
          // 对于具体版本号，查找对应 cycle 并验证
          let parts = ver.split(".").collect()
          let major_minor = "\{parts[0]}.\{parts[1]}"
          guard infos.search_by(fn(v) { v.cycle == major_minor }) is Some(_) else {
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          "v\{ver}"
        }
        _ =>
          raise fail(
            @i18n.t("error.invalid_version_detail", args={ "version": version }),
          )
      }
  }
}

///|
/// 获取 astral-sh/python-build-standalone 最新 release 的 tag
async fn get_standalone_tag() -> String {
  let cached = read_cache_file_content(PYTHON_STANDALONE_CACHE)
  if cached is Some(tag) && !tag.is_blank() {
    return tag.trim().to_owned()
  }
  let url = "https://api.github.com/repos/\{PYTHON_STANDALONE_REPO}/releases/latest"
  let (res, data) = @http.get(url, headers=@request.merge_detault_headers())
  guard res.code is (200..<300) else {
    raise fail(
      @i18n.t("python.cannot_fetch_standalone_tag", args={
        "code": res.code.to_string(),
        "reason": res.reason,
      }),
    )
  }
  let json = data.json()
  guard json is Object(map) && map.get("tag_name") is Some(String(tag)) else {
    raise fail(@i18n.t("python.cannot_parse_standalone_tag"))
  }
  write_cache_file_content(PYTHON_STANDALONE_CACHE, tag)
  tag
}

///|
/// 获取 Python 的下载信息
/// Python 3.x 各平台统一使用 astral-sh/python-build-standalone 预编译包
/// Python 2.x 无预编译包：
///   - Windows: 使用官方 MSI 安装包，通过 msiexec /a 提取
///   - Linux/macOS: 回退官方源码包，走编译流程
pub async fn Python::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo {
  // Python URL 中版本号不带 v 前缀
  let ver = if version.has_prefix("v") {
    version.sub(start=1).to_owned()
  } else {
    version
  }
  // Python 2.x 回退官方包
  let source_url = "\{PYTHON_RELEASE_URL}/\{ver}/Python-\{ver}.tgz"
  let source_info = { url: source_url, headers: Map([]), root_path_depth: 1 }
  if ver.has_prefix("2.") {
    match os_info.name {
      Windows => {
        // Python 2.7 仅提供 amd64 和 x86 MSI，ARM64 回退 x86（模拟运行）
        let msi_arch = if os_info.arch is Aarch64 { "" } else { "amd64" }
        let msi_url = if msi_arch == "" {
          "\{PYTHON_RELEASE_URL}/\{ver}/python-\{ver}.msi"
        } else {
          "\{PYTHON_RELEASE_URL}/\{ver}/python-\{ver}.\{msi_arch}.msi"
        }
        // msiexec /a 提取到目标目录，无额外嵌套层级
        return { url: msi_url, headers: Map([]), root_path_depth: 0 }
      }
      _ => return source_info
    }
  }
  let arch = if os_info.arch is Aarch64 { "aarch64" } else { "x86_64" }
  let triple = match os_info.name {
    Windows => "\{arch}-pc-windows-msvc"
    Linux => "\{arch}-unknown-linux-gnu"
    MacOS => "\{arch}-apple-darwin"
    name =>
      raise fail(
        @i18n.t("error.unsupported_os_detail", args={ "name": name.to_string() }),
      )
  }
  let tag = get_standalone_tag() catch { _ => return source_info }
  let url = "https://github.com/\{PYTHON_STANDALONE_REPO}/releases/download/\{tag}/cpython-\{ver}+\{tag}-\{triple}-install_only.tar.gz"
  // standalone 安装包解压后顶层为 python/ 目录
  { url, headers: Map([]), root_path_depth: 1 }
}

///|
/// 获取 Python 的预期 SHA256 校验值
/// Python 3.x 使用 standalone 预编译包，其 SHA256 与 python.org 源码包不同，跳过校验
/// Python 2.x:
///   - Windows MSI 安装包无独立 sha256 文件，跳过校验
///   - Linux/macOS 源码包从 python.org 获取 sha256 文件
pub async fn Python::get_expected_checksum(
  os_info : @os.OsInfo,
  version : String,
) -> String? {
  let ver = if version.has_prefix("v") {
    version.sub(start=1).to_owned()
  } else {
    version
  }
  if !ver.has_prefix("2.") {
    return None
  }
  // Python 2.x Windows MSI 无 sha256 校验文件，跳过
  if os_info.name is Windows {
    return None
  }
  let sha256_filename = "Python-\{ver}.tgz.sha256"
  let sha256_url = "\{PYTHON_RELEASE_URL}/\{ver}/\{sha256_filename}"

  // 应用镜像/代理配置
  let (_, global_config) = get_global_config()
  let ctx = UrlReplaceContext::new(
    sha256_url, "python", version, "linux", "x64",
  )
  let sha256_url = apply_global_config(sha256_url, global_config, ctx)

  let cache_file = "python_sha256_\{ver}.txt"
  let cached_content = read_cache_file_content(cache_file)
  let sha256_content = match cached_content {
    Some(content) => content
    None => {
      let (res, data) = @http.get(
        sha256_url,
        headers=@request.merge_detault_headers(),
      )
      if !(res.code is (200..<300)) {
        @log.warn(
          @i18n.t("python.cannot_fetch_shasums", args={
            "url": @utils.blue(sha256_url),
            "code": res.code.to_string(),
            "reason": res.reason,
          }),
        )
        return None
      }
      let content = data.text()
      write_cache_file_content(cache_file, content)
      content
    }
  }
  // sha256 文件格式: <hash>  <filename>
  _parse_node_shasums(sha256_content, "Python-\{ver}.tgz")
}

///|
pub fn Python::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let dir = version_dir(Tool::Python, version)
  match os {
    Windows => [dir, "python.exe"].join("/")
    MacOS | Linux => {
      // Python 2 使用 python，Python 3 使用 python3
      let exe_name = if dir.contains("/python/2.") ||
        dir.contains("/python/v2.") {
        "python"
      } else {
        "python3"
      }
      [dir, "bin", exe_name].join("/")
    }
    _ => raise fail(@i18n.t("python.unsupported_os"))
  }
}

///|
pub async fn Python::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  if program.is_blank() || version.is_blank() {
    raise fail(@i18n.t("error.specify_program_or_version"))
  }
  let tool_dir = version_dir(Tool::Python, version)
  let program_path = Python::get_exe_path(version)
  let exists = @fs.exists(program_path)
  let os = @os.get_os_name()
  let prog_low = program.to_lower()
  if prog_low == "python" || prog_low == "python3" {
    return ProgramExeInfo(
      "python",
      program_path,
      version,
      version,
      envs=Map([]),
      exists,
      Tool::Python,
      exists,
    )
  } else if prog_low == "pip" || prog_low == "pip3" {
    let pip_path = match os {
      Windows => [tool_dir, "Scripts", "pip.exe"].join("/")
      MacOS | Linux => [tool_dir, "bin", "pip3"].join("/")
      _ => ""
    }
    let pip_exists = @fs.exists(pip_path)
    return ProgramExeInfo(
      "pip",
      pip_path,
      version,
      version,
      envs=Map([]),
      pip_exists,
      Tool::Python,
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
