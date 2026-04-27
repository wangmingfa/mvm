///|
using @utils {red, green, yellow}

///|
fn[T : Show] log(prefix : String, msg : T) -> Unit {
  let time = @utils.get_date_str() catch { _ => "" }
  let prefix = if prefix.is_blank() { prefix } else { "[\{prefix}]" }
  let text = [time, prefix, msg.to_string()]
    .filter(v => !v.is_blank())
    .join(" ")
  println(text)
}

///|
pub fn[T : Show] success(msg : T) -> Unit {
  log("SUCCESS", green(msg))
}

///|
pub fn[T : Show] error(msg : T) -> Unit {
  if match_log_level(Error) {
    log("ERROR", red(msg))
  }
}

///|
pub fn[T : Show] warn(msg : T) -> Unit {
  if match_log_level(Warn) {
    log("WARN", yellow(msg))
  }
}

///|
pub fn[T : Show] info(msg : T) -> Unit {
  if match_log_level(Info) {
    log("INFO", msg)
  }
}

///|
pub fn[T : Show] debug(msg : T) -> Unit {
  if match_log_level(Debug) {
    log("DEBUG", msg)
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
