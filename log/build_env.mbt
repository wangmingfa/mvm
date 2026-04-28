///|
priv enum BuildEnv {
  Debug
  Release
}

///|
fn get_build_env() -> BuildEnv {
  if is_debug() {
    Debug
  } else {
    Release
  }
}
