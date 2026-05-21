///|
pub fn get_temp_dir(sub_dir? : String) -> String raise {
  guard @env.current_dir() is Some(dir) else {
    raise fail("获取目录失败")
  }
  @fs_ext.join_paths([
    dir,
    ".temp",
    if sub_dir is Some(sub_dir) {
      sub_dir
    } else {
      ""
    },
  ])
}

///|
pub fn get_temp_file(file_name : String) -> String raise {
  let dir = get_temp_dir()
  @fs_ext.join_path(dir, file_name)
}
