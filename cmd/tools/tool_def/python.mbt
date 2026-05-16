///| Python 官方发布源
const PYTHON_RELEASE_URL = "https://www.python.org/ftp/python"

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
  // 发布日期
  _release : String
  // 是否 LTS（Python 无 LTS，均为 false）
  _lts : Bool?
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
    raise fail("Python版本信息格式不对")
  }
  let infos : Array[PythonVersionInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e => raise fail("解析Python版本信息失败，原因：\{e}")
    }
  })
  guard infos.length() > 0 else {
    raise fail("Python版本信息为空")
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
        // 主版本号，如 "3.12"
        2 => {
          let search_version = if version.has_prefix("v") {
            version
          } else {
            "v\{version}"
          }
          // 去掉 v 前缀用于匹配 cycle
          let cycle = search_version.sub(start=1).to_owned()
          guard infos.search_by(fn(v) { v.cycle == cycle }) is Some(idx) else {
            raise fail("找不到版本：\{version}")
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
            raise fail("找不到版本：\{version}")
          }
          "v\{ver}"
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
/// 获取 Python 的下载信息
pub fn Python::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  // Python URL 中版本号不带 v 前缀
  let ver = if version.has_prefix("v") {
    version.sub(start=1).to_owned()
  } else {
    version
  }
  let url = match os_info.name {
    Windows => {
      let arch = if os_info.arch is Aarch64 { "arm64" } else { "amd64" }
      "\{PYTHON_RELEASE_URL}/\{ver}/python-\{ver}-embed-\{arch}.zip"
    }
    Linux => "\{PYTHON_RELEASE_URL}/\{ver}/Python-\{ver}.tgz"
    MacOS => "\{PYTHON_RELEASE_URL}/\{ver}/Python-\{ver}.tgz"
    name => raise fail("不支持的操作系统：\{name}")
  }
  let root_depth : UInt = match os_info.name {
    Windows => 0
    Linux => 1
    MacOS => 1
    _ => 0
  }
  { url, headers: {}, root_path_depth: root_depth }
}

///|
/// 获取 Python 的预期 SHA256 校验值
/// 从 python.org 获取 .sha256 文件
pub async fn Python::get_expected_checksum(
  os_info : @os.OsInfo,
  version : String,
) -> String? {
  let ver = if version.has_prefix("v") {
    version.sub(start=1).to_owned()
  } else {
    version
  }
  // macOS/Linux 使用源码包的 sha256 文件
  // Windows embeddable 包没有单独的 sha256 文件
  let sha256_filename = match os_info.name {
    Windows => return None
    Linux | MacOS => "Python-\{ver}.tgz.sha256"
    _ => return None
  }
  let sha256_url = "\{PYTHON_RELEASE_URL}/\{ver}/\{sha256_filename}"

  // 应用镜像/代理配置
  let (_, global_config) = get_global_config()
  let ctx = UrlReplaceContext::new(sha256_url, "python", version, "linux", "x64")
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
          "无法从 \{@utils.blue(sha256_url)} 获取 Python SHA256 校验文件: \{res.code} \{res.reason}",
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
  match os {
    Windows => [version_dir(Tool::Python, version), "python.exe"].join("/")
    MacOS | Linux =>
      [version_dir(Tool::Python, version), "bin", "python3"].join("/")
    _ => raise fail("不支持的操作系统")
  }
}