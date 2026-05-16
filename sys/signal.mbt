///|
/// 判断命令执行过程中是否被用户中断
pub fn is_cancelled(e : Error) -> Bool {
  e.to_string() == "Cancelled"
}
