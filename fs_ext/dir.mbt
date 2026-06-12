///|
/// 确保目录存在
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
/// 确保父目录存在
pub async fn ensure_parent_dir(path : String) -> Unit {
  if get_parent_dir(path) is Some(parent) {
    ensure_dir(parent)
  }
}

///|
/// 确保一串拼接起来的路径存在
pub async fn ensure_paths(paths : ArrayView[String]) -> Unit {
  let dir = join_paths(paths)
  ensure_dir(dir)
}

///|
pub async fn remove_dir(dir : String) -> Unit {
  @log.debug("开始删除目录 \{dir}")
  let exists = @fs.exists(dir)
  if @log.is_debug() && exists {
    @log.debug("目录信息 \{exists} | \{to_repr(@fs.kind(dir))}")
  }
  if exists && @fs.kind(dir) is Directory {
    @log.debug("删除目录 \{dir}")
    @fs.rmdir(dir, recursive=true)
  }
  @log.debug("删除目录 \{dir} 结束")
}
