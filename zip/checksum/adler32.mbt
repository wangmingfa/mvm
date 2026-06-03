///|
pub fn adler32(data : Bytes) -> UInt {
  let mut s1 : UInt = 1U
  let mut s2 : UInt = 0U
  let len = data.length()
  let mut i = 0
  while i < len {
    let remaining = len - i
    let block_len = if remaining < 5552 { remaining } else { 5552 }
    let end = i + block_len
    while i < end {
      s1 = s1 + data[i].to_uint()
      s2 = s2 + s1
      i = i + 1
    }
    s1 = s1 % 65521U
    s2 = s2 % 65521U
  }
  (s2 << 16) + s1
}
