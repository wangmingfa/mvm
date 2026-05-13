///|
using @utils {red, green, yellow}

///|
let log_line_count : Ref[Int] = Ref(0)

///|
pub fn add_log_lines(lines? : Int = 1) -> Unit {
  log_line_count.val += lines
}

///|
pub fn add_log_lines_by_content(content : String) -> Int {
  let lines = content.split("\n").to_array().length()
  add_log_lines(lines~)
  lines
}

///|
fn[T : Debug] log(prefix : String, loc? : String = "", msg : T) -> Unit {
  let time = @utils.get_date_str() catch { _ => "" }
  let prefix = if prefix.is_blank() { prefix } else { "[\{prefix}]" }
  // 右边补齐空格，确保日志内容左侧对齐
  let pad_right = " ".repeat(7 - prefix.length())
  let prefix = "\{prefix}\{pad_right}"
  let msg_str = to_repr(msg).to_string()
  let arr = if is_debug() || is_debug_log_level() {
    // 只有debug模式，或者开了debug日志时，才显示日志时间、日志类型，以及代码位置
    [time, prefix, loc, msg_str]
  } else {
    [msg_str]
  }
  let text = arr.filter(v => !v.is_blank()).join(" ")

  // 记录行数
  let _ = add_log_lines_by_content(text)
  // println("行数: \{log_line_count.val}")

  println(text)
}

///|
const FAILED_KEY = "FAILED:"

///|
pub fn println_error(e : Error) -> Unit {
  let msg = match e {
    Failure::Failure(msg) => {
      let start_index = if is_release() &&
        msg.find(FAILED_KEY) is Some(start_index) {
        start_index + FAILED_KEY.length()
      } else {
        0
      }
      msg[start_index:].trim().to_owned()
    }
    _ => {
      let msg = e.to_string()
      if msg == "Cancelled" {
        println("")
        "操作已取消"
      } else {
        msg
      }
    }
  }
  error(msg)
}

///|
fn get_loc_msg(loc : SourceLoc) -> String {
  if get_build_env() is Debug {
    return loc.to_string()
  }
  return ""
}

///|
#callsite(autofill(loc))
pub fn[T : Debug] success(msg : T, loc~ : SourceLoc) -> Unit {
  log("INFO", loc=get_loc_msg(loc), green(msg))
}

///|
#callsite(autofill(loc))
pub fn[T : Debug] error(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Error) {
    log("ERROR", loc=get_loc_msg(loc), red(msg))
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Debug] warn(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Warn) {
    log("WARN", loc=get_loc_msg(loc), yellow(msg))
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Debug] info(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Info) {
    log("INFO", loc=get_loc_msg(loc), msg)
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Debug] debug(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Debug) {
    log("DEBUG", loc=get_loc_msg(loc), msg)
  }
}

///|
test "log" {
  let blue_text = @utils.blue("蓝色文字")
  success("操作成功了")
  success("操作 \{blue_text} 成功了")
  error("操作 \{blue_text} 失败了")
  warn("警告 \{blue_text} 信息")
  info("开始 \{blue_text} 操作")
  debug("调试 \{blue_text} 信息")
}

///|
extern "C" fn c_enter_alternate_screen() -> Unit = "enter_alternate_screen"

///|
extern "C" fn c_exit_alternate_screen() -> Unit = "exit_alternate_screen"

///|
pub extern "C" fn clear_lines(lines : Int) -> Unit = "clear_lines"

///|
pub fn clear_all_lines() -> Unit {
  clear_lines(log_line_count.val)
}

///|
fn enter_alternate_screen() -> Unit {
  c_enter_alternate_screen()
  // println("\u{001B}[?1049h\u{001B}[2J\u{001B}[H]")
}

///|
fn exit_alternate_screen() -> Unit {
  c_exit_alternate_screen()
  // println("\u{001B}[?1049l")
}

///|
pub fn enter_alternate_screen_on_release_mode() -> Unit {
  if is_release() {
    enter_alternate_screen()
  }
}

///|
pub fn exit_alternate_screen_on_release_mode() -> Unit {
  if is_release() {
    exit_alternate_screen()
  }
}

///|
test "alternate_screen" {
  println("0")
  enter_alternate_screen()
  println("1")
  println("2")
  println("3")
  println("4")
  exit_alternate_screen()
  println("5")
}
