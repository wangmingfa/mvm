///|
#cfg(platform="windows")
#borrow(bytes)
extern "C" fn c_gbk_to_utf8(bytes : Bytes, len : Int) -> String = "gbk_to_utf8"

///|
#cfg(platform="windows")
pub fn gbk_to_utf8(bytes : Bytes) -> String {
  c_gbk_to_utf8(bytes, bytes.length())
}

///|
#cfg(platform="windows")
test "convert_to_utf8" {
  // gbk编码的“你好啊“
  let text = Bytes::from_array([
    0xC4, 0xE3, // 你
     0xBA, 0xC3, // 好
     0xB0, 0xA1, // 啊
  ])
  debug_inspect(
    gbk_to_utf8(text),
    content=(
      #|"你好啊"
    ),
  )
}
