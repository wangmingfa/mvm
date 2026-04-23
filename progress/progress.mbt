///|
#borrow(suffix)
extern "C" fn c_progress_bar(
  progress : Int64,
  total : Int64,
  suffix : Bytes,
) -> Unit = "progress_bar"

///|
pub extern "C" fn clear_progress() -> Unit = "clear_progress"

///|
/// 一个辅助函数，将 MoonBit String 转换为 C 期望的 null-terminated byte array
fn string_to_c_bytes(s : String) -> Bytes {
  // let arr = s.to_bytes().to_array()
  let arr = @utf8.encode(s).to_array()
  // 确保以 \0 结尾
  if arr.last() != Some(0) {
    arr.push(0)
  }
  Bytes::from_array(arr)
}

///|
pub fn progress_bar(progress : Int64, total : Int64, suffix? : String) -> Unit {
  c_progress_bar(
    progress,
    total,
    string_to_c_bytes(if suffix is Some(s) { s } else { "" }),
  )
}

///|
async test "progress_bar" {
  for i in 0..<=100 {
    progress_bar(Int64::from_int(i + 1), 100, suffix="downloading...")
    @async.sleep(100)
  }
  println("")
}
