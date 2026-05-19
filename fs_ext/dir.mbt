///|
/// 确保目录存在（跨平台方案，天然容忍并发冲突）
/// Unix: 使用 mkdir -p（自动创建中间目录 + 目录已存在时静默成功）
/// Windows: 使用 cmd mkdir（默认创建中间目录，目录已存在时需兜底检查）
pub async fn ensure_dir(dir : String) -> Unit {
  // if (try? @fs.kind(dir)) is Ok(Directory) {
  //   raise fail("\{dir} 不是文件夹")
  // }
  // let os = @os.get_os_name()
  // let exit_code = match os {
  //   Windows => @process.run("cmd", ["/c", "mkdir", dir])
  //   _ => @process.run("mkdir", ["-p", dir])
  // }
  // if exit_code != 0 {
  //   // 并发场景下其他进程可能已创建该目录，兜底检查
  //   guard (try? @fs.kind(dir)) is Ok(Directory) else {
  //     raise fail("创建文件夹 \{dir} 失败，exit_code=\{exit_code}")
  //   }
  // }
  guard @fs.exists(dir) is false else { return }
  @fs.mkdir(dir, recursive=true)
}

///|
pub async fn remove_dir(dir : String) -> Unit {
  if @fs.exists(dir) {
    @fs.rmdir(dir, recursive=true)
  }
}
