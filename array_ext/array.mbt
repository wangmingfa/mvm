///|
pub fn remove_prefix(arr : Array[String], prefix : String) -> Array[String] {
  arr.map(v => {
    if v.has_prefix(prefix) {
      v[prefix.length():].to_string()
    } else {
      v
    }
  })
}

///|
test "remove_prefix" {
  let arr = ["abc_1", "abc_2", "ccc_3"]
  inspect(
    remove_prefix(arr, "abc_"),
    content=(
      #|["1", "2", "ccc_3"]
    ),
  )
}
