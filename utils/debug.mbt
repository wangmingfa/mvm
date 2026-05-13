///|
pub fn[T : Debug] debug_to_string(debug : T) -> String {
  to_repr(debug).to_string()[1:-1].to_owned()
}
