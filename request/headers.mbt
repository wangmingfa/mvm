///|
/// filename*=UTF-8''...
const PATTERN_STAR = "filename\\*=[Uu][Tt][Ff]-8''(?<name>[^;\\r\\n]+)"

///|
/// filename="..."
const PATTERN_PLAIN = "filename=\"*(?<name>[^\"]+)\"*"

///|
fn get_file_name(url : String, headers : Map[String, String]) -> String {
  // 先从content-disposition中获取文件名
  if @utils.get_from_map_ignore_case(headers, "Content-Disposition")
    is Some(disposition) &&
    disposition.contains("filename") {
    for pattern in [PATTERN_STAR, PATTERN_PLAIN] {
      let regexp = @regexp.compile(pattern) catch {
        _ =>
          // println("正则表达式编译错误: \{pattern}")
          continue
      }
      guard regexp.match_(disposition) is Some(result) else {
        // println("未匹配到文件名，尝试下一个模式...")
        continue
      }
      if result.results().get(1) is Some(file_name) &&
        file_name is Some(file_name) {
        return file_name.to_owned()
      }
    }
  }
  let arr = url.split("/").filter(v => v.trim() != "").collect()
  let last_part = arr[arr.length() - 1]
  // 去掉URL参数
  let last_part = last_part.split("?").collect()[0]
  // 如果是HTML页面，则使用域名作为文件名
  if @utils.get_from_map_ignore_case(headers, "Content-Type")
    is Some(content_type) &&
    content_type.contains("text/html") {
    "\{last_part}.html"
  } else {
    last_part.to_owned()
  }
}
