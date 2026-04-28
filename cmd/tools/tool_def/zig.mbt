///|
const ZIG_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
const ZIG_INDEX_URL = "https://nodejs.org/dist/index.json"

///|
const ZIG_INDEX_CACHE_FILE = "zig_index.json"

///|
pub struct Zig {}

///|
async fn Zig::get_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  ...
}

///|
pub async fn Zig::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  ...
}

///|
fn Zig::check_os_compatiable(
  os : @os.OsInfo,
  error_msg_tpl? : String = "版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
) -> String raise {
  ...
}

///|
pub fn Zig::get_download_url(
  os_info : @os.OsInfo,
  version : String,
) -> String raise {
  ...
}

///|
fn Zig::get_exe_path(version : String) -> String {
  // TODO
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Node, version), "bin", "node", suffix]
  .filter(v => !v.is_blank())
  .join("/")
}
