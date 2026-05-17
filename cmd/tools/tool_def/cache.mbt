///|
/// MVM 主目录下的缓存子目录
pub fn cache_dir() -> String raise {
  @fs_ext.join_path(mvm_home(), ".cache")
}

///|
pub fn temp_dir() -> String raise {
  @fs_ext.join_path(mvm_home(), ".temp")
}

///|
/// 全局 no_cache 模式标志（使用 Ref 作为可变容器，MoonBit 不支持模块级 let mut）
/// 设置为 true 时，read_cache_file_content 将返回 None，强制重新下载索引和校验值文件
/// write_cache_file_content 仍会写入缓存（同一安装会话内的后续步骤需要读取）
let no_cache_flag : Ref[Bool] = Ref(false)

///|
/// 设置 no_cache 模式（安装时传入 --no-cache 参数时设为 true）
pub fn set_no_cache_mode(no_cache : Bool) -> Unit {
  no_cache_flag.val = no_cache
}

///|
/// 获取当前 no_cache 模式状态
pub fn is_no_cache_mode() -> Bool {
  no_cache_flag.val
}

///|
/// 从缓存读取文件内容
/// 当 no_cache 模式开启时，返回 None（强制重新下载）
pub async fn read_cache_file_content(cache_file_path : String) -> String? {
  if is_no_cache_mode() {
    @log.debug("no_cache 模式：跳过读取缓存 \{cache_file_path}")
    return None
  }
  let file_path = @fs_ext.join_path(cache_dir(), cache_file_path)
  if @fs.exists(file_path) {
    return Some(@fs.read_file(file_path).text())
  }
  return None
}

///|
pub async fn write_cache_file_content(
  cache_file_path : String,
  content : String,
) -> Unit {
  let file_path = @fs_ext.join_path(cache_dir(), cache_file_path)
  let parent_dir = @fs_ext.get_parent_dir(file_path)
  guard parent_dir is Some(parent_dir)
  @fs_ext.ensure_dir(parent_dir)
  @fs.write_file(file_path, content, create_mode=CreateOrTruncate)
}

///|
/// 共享 helper: resolve tool version with cache-first strategy
/// 1. If version_count == 3, try reading from cache and parsing
/// 2. If cache miss or parse result is blank, fetch from remote
/// 3. Save the remote response to cache
/// 4. Parse with the provided function
pub async fn get_target_version_with_cache(
  cache_file : String,
  url : String,
  tool_name : String,
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  parse_fn : (@os.OsInfo, String, Int, Json) -> String raise,
  headers? : Map[String, String] = {},
) -> String {
  if version_count == 3 {
    let cache_file_content = read_cache_file_content(cache_file)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = parse_fn(os, version, version_count, json) catch {
        _ => ""
      }
      if !target_version.is_blank() {
        return target_version
      }
    }
  }
  let (res, data) = @http.get(
    url,
    headers=@request.merge_detault_headers(headers~),
  )
  guard res.code is (200..<300) else {
    raise fail(
      "无法获取到\{tool_name}版本信息（HTTP \{res.code} \{res.reason}，URL: \{url}）",
    )
  }
  let json = data.json()
  write_cache_file_content(cache_file, json.stringify(indent=2))
  parse_fn(os, version, version_count, json)
}

///|
test "no_cache_mode_toggle" {
  // 默认 no_cache 模式为 false
  guard !is_no_cache_mode() else { fail("no_cache should be false by default") }
  // 设置为 true
  set_no_cache_mode(true)
  guard is_no_cache_mode() else {
    fail("no_cache should be true after set_no_cache_mode(true)")
  }
  // 恢复为 false
  set_no_cache_mode(false)
  guard !is_no_cache_mode() else {
    fail("no_cache should be false after set_no_cache_mode(false)")
  }
}

///|
async test "cache_read_write_normal_mode" {
  // 正常模式：写入缓存后可以读取
  set_no_cache_mode(false)
  let test_key = "test/\{@async.now()}"
  let test_content = "hello cache test"
  write_cache_file_content(test_key, test_content)
  let read_result = read_cache_file_content(test_key)
  guard read_result is Some(content) else {
    fail("should read cache content in normal mode")
  }
  guard content == test_content else {
    fail("cache content mismatch: \{content}")
  }
}

///|
async test "cache_read_no_cache_mode" {
  // no_cache 模式：写入缓存后读取仍返回 None
  set_no_cache_mode(false)
  let test_key = "test_nocache/\{@async.now()}"
  let test_content = "hello no_cache test"
  write_cache_file_content(test_key, test_content)
  // 开启 no_cache 模式
  set_no_cache_mode(true)
  let read_result = read_cache_file_content(test_key)
  guard read_result is None else { fail("should return None in no_cache mode") }
  // 恢复
  set_no_cache_mode(false)
}
