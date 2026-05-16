///|
pub fn[T : Show] show_to_string(s : T) -> String {
  Show::to_string(s)
}

///|
pub fn[T : Show] array_to_string(a : Array[T]) -> String {
  a.map(a => show_to_string(a)).join(", ")
}

///|
pub(open) trait ToStr {
  to_str(Self) -> String
}

///|
pub impl ToStr for String with to_str(s) {
  s
}

///|
pub impl ToStr for StringView with to_str(s) {
  s.to_owned()
}

///|
pub impl[T : ToStr] ToStr for Array[T] with to_str(s) {
  "[" + s.map(v => v.to_str()).join(", ") + "]"
}

///|
fn is_cjk(c : Char) -> Bool {
  let cp = c.to_int()
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x2E80 && cp <= 0x2EFF) ||
  (cp >= 0x3000 && cp <= 0x303F) ||
  (cp >= 0x3040 && cp <= 0x33FF) ||
  (cp >= 0xFF01 && cp <= 0xFF60) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0xFE30 && cp <= 0xFE6F) ||
  (cp >= 0xFFE0 && cp <= 0xFFE6)
}

///|
pub fn display_width(s : String) -> Int {
  let mut width = 0
  for c in s {
    width += if is_cjk(c) { 2 } else { 1 }
  }
  width
}

///|
pub fn pad_right(s : String, width : Int) -> String {
  let dw = display_width(s)
  if dw >= width {
    s
  } else {
    s + " ".repeat(width - dw)
  }
}

///|
test "display_width 纯ASCII" {
  inspect(
    display_width("hello"),
    content=(
      #|5
    ),
  )
  inspect(
    display_width(""),
    content=(
      #|0
    ),
  )
  inspect(
    display_width("abc 123"),
    content=(
      #|7
    ),
  )
}

///|
test "display_width CJK字符" {
  // 中文字符宽度为2
  inspect(
    display_width("你好"),
    content=(
      #|4
    ),
  )
  // 混合ASCII和CJK
  inspect(
    display_width("hello你好"),
    content=(
      #|9
    ),
  )
  // 全角符号
  inspect(
    display_width("！"),
    content=(
      #|2
    ),
  )
}

///|
test "pad_right 纯ASCII" {
  // 短字符串填充到指定宽度
  let result = pad_right("hi", 5)
  guard result.length() == 5 else {
    fail("expected length 5, got \{result.length()}: \{result}")
  }
  guard result.has_prefix("hi") else {
    fail("expected starts with 'hi', got \{result}")
  }
  // 已够宽，不填充
  let result2 = pad_right("hello", 3)
  guard result2.length() == 5 else {
    fail("expected length 5 (unchanged), got \{result2.length()}")
  }
}

///|
test "pad_right CJK字符" {
  // 中文宽度为2，填充时考虑实际显示宽度
  // "你好" display_width=4, 目标宽度6, 需填充2个空格
  // String.length() 返回字符数：2个中文字 + 2个空格 = 4
  let result = pad_right("你好", 6)
  guard result.length() == 2 + 2 else {
    fail("expected length 4 (2 CJK chars + 2 spaces), got \{result.length()}")
  }
  guard display_width(result) == 6 else {
    fail("expected display_width 6, got \{display_width(result)}")
  }
  // 混合字符填充：display_width = 9, 需填充 3 个空格
  // "hello你好" = 5 ASCII + 2 CJK chars, string length = 7, display_width = 9
  // 目标宽度 12, 填充 3 空格, 总 string length = 7 + 3 = 10
  let result2 = pad_right("hello你好", 12)
  guard result2.length() == 7 + 3 else {
    fail("expected length 10, got \{result2.length()}")
  }
  guard display_width(result2) == 12 else {
    fail("expected display_width 12, got \{display_width(result2)}")
  }
}
