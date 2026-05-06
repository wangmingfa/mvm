///|
/// 一个辅助函数，将 MoonBit String 转换为 C 期望的 null-terminated byte array
pub fn string_to_c_bytes(s : String) -> Bytes {
  // let arr = s.to_bytes().to_array()
  let arr = @utf8.encode(s).to_array()
  // 确保以 \0 结尾
  if arr.last() != Some(0) {
    arr.push(0)
  }
  Bytes::from_array(arr)
}
