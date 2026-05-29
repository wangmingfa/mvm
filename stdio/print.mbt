///|
#borrow(str)
extern "C" fn c_print(str : Bytes) -> Unit = "print"

///|
extern "C" fn c_read_line() -> String = "read_line"

///|
#borrow(tools_json, preselected, title)
extern "C" fn c_interactive_select_tools(
  tools_json : Bytes,
  preselected : Bytes,
  title : Bytes,
) -> String = "interactive_select_tools_c"

///|
pub extern "C" fn flush_stdout() -> Unit = "flush_stdout"

///|
pub extern "C" fn clear_lines(lines : Int) -> Unit = "clear_lines"

///|
pub fn print(str : String) -> Unit {
  c_print(@ffi.string_to_c_bytes(str))
}

///|
/// 从标准输入读取一行文本
pub fn read_line() -> String {
  c_read_line()
}

///|
/// 交互式选择工具（C 语言实现）
/// tools: 工具名数组
/// preselected: 预选中工具名数组
/// title: 显示在顶部的标题文本（高亮显示）
/// 返回: 逗号分隔的选中工具名
pub fn interactive_select_tools_c(
  tools : Array[String],
  preselected : Array[String],
  title : String,
) -> String {
  let tools_str = tools.join(",")
  let preselected_str = preselected.join(",")
  c_interactive_select_tools(
    @ffi.string_to_c_bytes(tools_str),
    @ffi.string_to_c_bytes(preselected_str),
    @ffi.string_to_c_bytes(title),
  )
}

///|
test "print" {
  print("a")
  print("b")
  print("c")
  print("d")
  print("e")
  println("")
}
