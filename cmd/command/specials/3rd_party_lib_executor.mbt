///|
pub fn run_3rd_party_executor(
  name : StringView,
  args : ArrayView[String],
) -> Unit raise {
  raise fail("\{name} \{args}")
}
