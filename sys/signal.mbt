///|
/// 判断命令执行过程中是否被用户中断
pub fn is_cancelled(e : Error) -> Bool {
  let msg = match e {
    Failure::Failure(msg) => msg
    _ => e.to_string()
  }
  msg == "Cancelled"
}
