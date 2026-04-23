///|
pub fn get_from_map_ignore_case(
  map : Map[String, String],
  key : String,
) -> String? {
  let lower_key = key.to_lower()
  for k in map.keys() {
    if k.to_lower() == lower_key {
      return map.get(k)
    }
  }
  return None
}
