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
