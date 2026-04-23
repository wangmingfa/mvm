///|
pub async fn mv(
  src : String,
  dest : String,
  include_root? : Bool = true,
) -> Unit {
  guard @fs.exists(src) else { raise fail("路径不存在 \{src}") }
  let kind = @fs.kind(src)
  let is_dir = match kind {
    Regular => {
      // 文件
      ensure_dir(dest)
      let name = get_path_name(src)
      let dest_file_path = get_dest_path(dest, name)
      copy_file(src, dest_file_path)
      false
    }
    Directory => {
      copy_dir(src, dest, include_root~)
      true
    }
    _ => raise fail("不支持的类型 \{@debug.to_string(kind)}")
  }
  if is_dir {
    @fs.rmdir(src[0:], recursive=true)
  } else {
    @fs.remove(src[0:])
  }
}

///|
async fn copy_file(src : String, dest : String) -> Unit {
  let src_file = @fs.open(src, mode=ReadOnly)
  defer src_file.close()
  let dest_file = @fs.open(dest, mode=WriteOnly, create=PERMISSION_FILE)
  defer dest_file.close()
  dest_file.write_reader(src_file)
}

///|
async fn copy_dir(
  from : String,
  to : String,
  include_root? : Bool = true,
) -> Unit {
  let dest_dir = if include_root {
    let name = get_path_name(from)
    let dest_dir = get_dest_path(to, name)
    ensure_dir(dest_dir)
    dest_dir
  } else {
    ensure_dir(to)
    to
  }
  let entries = @fs.readdir(from)
  for entry in entries {
    let src_path = "\{from}/\{entry}"
    let kind = @fs.kind(src_path)
    match kind {
      Regular => {
        let dest_path = "\{dest_dir}/\{entry}"
        copy_file(src_path, dest_path)
      }
      Directory => copy_dir(src_path, dest_dir)
      _ => ignore(())
    }
  }
}

///|
async fn get_dest_path(dest : String, name : String) -> String {
  let mut count = 0
  while count >= 0 {
    let path = if count > 0 {
      let arr = name.split(".").to_array()
      let len = arr.length()
      let prefix = arr[0:len - 1].join(".")
      let suffix = arr[len - 1]
      let suffix = if suffix.is_blank() { "" } else { ".\{suffix}" }
      "\{dest}/\{prefix}-\{count}\{suffix}"
    } else {
      "\{dest}/\{name}"
    }
    if @fs.exists(path) {
      count += 1
      continue
    }
    break path
  } nobreak {
    "\{dest}/\{name}"
  }
}

///|
async fn get_all_sub_dir_or_file_path(
  path : String,
  include_root? : Bool = false,
) -> Array[String] {
  let arr = []
  if include_root {
    arr.push(path)
  }
  if @fs.exists(path) {
    let pending_dirs = [path]
    while pending_dirs.length() > 0 {
      let dir = pending_dirs.remove(0)
      for entry in @fs.readdir(dir) {
        let path = Path(dir).join(entry).to_string()
        arr.push(path)
        match @fs.kind(path) {
          Directory => pending_dirs.push(path)
          _ => ignore("无需处理")
        }
      }
    }
    arr.sort()
  } else {
    println("路径不存在：\{path}")
  }
  arr
}

///|
async fn generate_tmp_dir_and_files() -> (String, Array[String]) {
  let dir_or_files = []
  // 生成临时文件
  let file_content = "hello world, MoonBit!"
  let temp_dir = get_tmp_dir()
  let src_root_dir = temp_dir.join_path("src_\{@async.now()}")
  ensure_dir(src_root_dir)
  let src_root_file_path = "\{src_root_dir}/root.txt"
  @fs.write_file(
    src_root_file_path,
    "\{file_content}\nroot",
    create=PERMISSION_FILE,
  )
  dir_or_files.push(src_root_dir)
  dir_or_files.push(src_root_file_path)
  // 创建临时文件夹
  for i in 0..<=10 {
    let tmp_dir_in_src_root_dir = "\{src_root_dir}/dir_\{i}"
    ensure_dir(tmp_dir_in_src_root_dir)
    dir_or_files.push(tmp_dir_in_src_root_dir)
    // 写入内容
    let tmp_file_in_src_root_dir = "\{tmp_dir_in_src_root_dir}/\{i}.txt"
    let content = "\{file_content}\n\{i}"
    @fs.write_file(tmp_file_in_src_root_dir, content, create=PERMISSION_FILE)
    dir_or_files.push(tmp_file_in_src_root_dir)
  }
  dir_or_files.sort()
  (src_root_dir, dir_or_files)
}

///|
async test "get_all_sub_dir_or_file_path" {
  let (dest_path, tmp_dir_and_files) = generate_tmp_dir_and_files()
  let validate_dir_and_fiels = get_all_sub_dir_or_file_path(
    dest_path,
    include_root=true,
  )
  assert_eq(tmp_dir_and_files, validate_dir_and_fiels)
}

///|
fn get_tmp_dir() -> String {
  guard @env.current_dir() is Some(current_dir)
  "\{current_dir}/.temp"
}

///|
async test "move file" {
  // 生成临时文件
  let file_content = "hello world, MoonBit!"
  let temp_dir = get_tmp_dir()
  ensure_dir(temp_dir)
  let src_random_name = @env.now()
  let src_file_path = "\{temp_dir}/mv_\{src_random_name}.txt"
  let file_name = get_path_name(src_file_path)
  @fs.write_file(src_file_path, file_content, create=PERMISSION_FILE)
  let dest_path = "\{temp_dir}/\{src_random_name}"
  // 移动
  mv(src_file_path, dest_path)
  // 比较是否成功
  let dest_file_paht = "\{dest_path}/\{file_name}"
  println("比较：\{src_file_path}  vs  \{dest_file_paht}")
  if @fs.exists(dest_file_paht) {
    let dest_file_content = @fs.read_file(dest_file_paht).text()
    if dest_file_content == file_content {
      return
    }
  }
  raise fail("move失败")
}

///|
async test "move dir" {
  let (src_root_dir, src_dir_and_files) = generate_tmp_dir_and_files()
  let dest_path = src_root_dir
    .join_path("../")
    .join_path("dest_\{@async.now()}")
  // 移动
  mv(src_root_dir, dest_path)
  let dest_dir_and_files = get_all_sub_dir_or_file_path(
    dest_path,
    include_root=false,
  )
  // 将路径中的前缀目录去掉，进行比较
  guard get_parent_dir(src_root_dir) is Some(src_root_parent_dir)
  inspect(
    src_dir_and_files.remove_prefix(src_root_parent_dir),
    content=dest_dir_and_files.remove_prefix(dest_path).to_string(),
  )
  // 删除临时文件
  @fs.rmdir(dest_path, recursive=true)
}
