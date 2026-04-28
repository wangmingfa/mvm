///|
using @utils {red, green, yellow}

///|
fn[T : Show] log(prefix : String, loc? : String = "", msg : T) -> Unit {
  let time = @utils.get_date_str() catch { _ => "" }
  let prefix = if prefix.is_blank() { prefix } else { "[\{prefix}]" }
  // 右边补齐空格，确保日志内容左侧对齐
  let pad_right = " ".repeat(7 - prefix.length())
  let prefix = "\{prefix}\{pad_right}"
  let text = [time, prefix, loc, msg.to_string()]
    .filter(v => !v.is_blank())
    .join(" ")
  println(text)
}

///|
const FAILED_KEY = "FAILED:"

///|
pub fn println_error(e : Error) -> Unit {
  let msg = match e {
    Failure::Failure(msg) => {
      let start_index = if !is_debug() &&
        msg.find(FAILED_KEY) is Some(start_index) {
        start_index + FAILED_KEY.length()
      } else {
        0
      }
      msg[start_index:].trim().to_string()
    }
    _ => e.to_string()
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
pub fn[T : Show] success(msg : T, loc~ : SourceLoc) -> Unit {
  log("INFO", loc=get_loc_msg(loc), green(msg))
}

///|
#callsite(autofill(loc))
pub fn[T : Show] error(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Error) {
    log("ERROR", loc=get_loc_msg(loc), red(msg))
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Show] warn(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Warn) {
    log("WARN", loc=get_loc_msg(loc), yellow(msg))
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Show] info(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Info) {
    log("INFO", loc=get_loc_msg(loc), msg)
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Show] debug(msg : T, loc~ : SourceLoc) -> Unit {
  if match_log_level(Debug) {
    log("DEBUG", loc=get_loc_msg(loc), msg)
  }
}

///|
test "log" {
  success("操作成功了")
  error("操作失败了")
  warn("警告信息")
  info("开始操作")
  debug("调试信息")
}
