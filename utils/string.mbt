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
