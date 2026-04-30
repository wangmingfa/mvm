///|
pub fn[T : Show] option_to_string(o : T?) -> String {
  match o {
    None => "None"
    Some(t) => "Some(\{t})"
  }
}
