///|
pub async fn mv(
  src : String,
  dest : String,
  remove_dest_if_exists? : Bool = false,
) -> Unit {
  guard @fs.exists(src) else { raise fail("路径不存在 \{src}") }

  let mut dest_exists = @fs.exists(dest)
  // dest存在时，删除掉
  if remove_dest_if_exists && dest_exists {
    @log.debug("删除目标文件 \{dest}")
    remove_if_exists(dest)
    dest_exists = false
  }

  // dest 已存在且是目录时，将 src 移入该目录内（类似 Unix mv 命令行为）
  // 直接调用 @fs.kind 判断，避免 exists 和 kind 之间的竞争条件
  if dest_exists {
    let kind_result = try @fs.kind(dest) |> Ok catch {
      e => Err(e)
    }
    if kind_result is Ok(Directory) {
      let name = get_path_name(src)
      let final_dest = join_path(dest, name)
      @log.debug("目标为 \{final_dest}")
      @fs.rename(src, final_dest)
      return
    }
  }
  // 确保父目录存在
  ensure_parent_dir(dest)
  @fs.rename(src, dest)
}

///|
pub async fn copy(src : String, dest : String) -> Unit {
  @log.debug("拷贝 \{src} => \{dest}")
  let src_file = @fs.open(src, mode=ReadOnly)
  defer src_file.close()
  @log.debug("打开目标文件 \{dest} | \{@fs.exists(dest)}")
  let dest_file = @fs.open(dest, mode=WriteOnly, create_mode=CreateOrTruncate)
  defer dest_file.close()
  @log.debug("写入目标文件 \{dest}")
  dest_file.write_reader(src_file)
}

///|
// async fn copy_dir(
//   from : String,
//   to : String,
//   include_root? : Bool = true,
// ) -> Unit {
//   let dest_dir = if include_root {
//     let name = get_path_name(from)
//     let dest_dir = get_dest_path(to, name)
//     ensure_dir(dest_dir)
//     dest_dir
//   } else {
//     ensure_dir(to)
//     to
//   }
//   let entries = @fs.readdir(from)
//   for entry in entries {
//     let src_path = "\{from}/\{entry}"
//     let kind = @fs.kind(src_path)
//     match kind {
//       Regular => {
//         let dest_path = "\{dest_dir}/\{entry}"
//         copy(src_path, dest_path)
//       }
//       Directory => copy_dir(src_path, dest_dir)
//       _ => ignore(())
//     }
//   }
// }

///|
// async fn get_dest_path(dest : String, name : String) -> String {
//   let mut count = 0
//   while count >= 0 {
//     let path = if count > 0 {
//       let arr = name.split(".").to_array()
//       let len = arr.length()
//       let prefix = arr[0:len - 1].join(".")
//       let suffix = arr[len - 1]
//       let suffix = if suffix.is_blank() { "" } else { ".\{suffix}" }
//       "\{dest}/\{prefix}-\{count}\{suffix}"
//     } else {
//       "\{dest}/\{name}"
//     }
//     if @fs.exists(path) {
//       count += 1
//       continue
//     }
//     break path
//   } nobreak {
//     "\{dest}/\{name}"
//   }
// }

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
async fn generate_tmp_dir_and_files(
  tag? : String = "",
) -> (String, Array[String]) {
  let dir_or_files = []
  // 生成临时文件
  let file_content = "hello world, MoonBit!"
  let temp_dir = get_tmp_dir()
  // tag 用于区分并发测试调用，避免时间戳冲突
  let src_root_dir = temp_dir.join_path("src_\{tag}_\{@async.now()}")
  ensure_dir(src_root_dir)
  let src_root_file_path = "\{src_root_dir}/root.txt"
  @fs.write_file(
    src_root_file_path,
    "\{file_content}\nroot",
    create_mode=CreateOrTruncate,
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
    @fs.write_file(
      tmp_file_in_src_root_dir,
      content,
      create_mode=CreateOrTruncate,
    )
    dir_or_files.push(tmp_file_in_src_root_dir)
  }
  dir_or_files.sort()
  (src_root_dir, dir_or_files)
}

///|
async test "get_all_sub_dir_or_file_path" {
  let (dest_path, tmp_dir_and_files) = generate_tmp_dir_and_files(tag="get_all")
  let validate_dir_and_fiels = get_all_sub_dir_or_file_path(
    dest_path,
    include_root=true,
  )
  @debug.assert_eq(tmp_dir_and_files, validate_dir_and_fiels)
}

///|
fn get_tmp_dir() -> String {
  guard @env.current_dir() is Some(current_dir)
  "\{current_dir}/.temp"
}

///|
async test "move file" {
  // 测试 mv 将文件重命名到不存在的新路径
  let file_content = "hello world, MoonBit!"
  let temp_dir = get_tmp_dir()
  ensure_dir(temp_dir)
  let timestamp = @async.now()
  let src_file_path = "\{temp_dir}/mv_src_\{timestamp}.txt"
  @fs.write_file(src_file_path, file_content, create_mode=CreateOrTruncate)
  // dest 不存在，mv 将 src 重命名为 dest
  let dest_path = "\{temp_dir}/mv_dest_\{timestamp}.txt"
  mv(src_file_path, dest_path)
  // 验证目标文件存在且内容一致
  guard @fs.exists(dest_path) else {
    raise fail("目标文件不存在：\{dest_path}")
  }
  let dest_file_content = @fs.read_file(dest_path).text()
  guard dest_file_content == file_content else {
    raise fail("move 失败：文件内容不一致")
  }
  // 清理
  @fs.remove(dest_path)
}

///|
async test "move file into dir" {
  // 测试 mv 将文件移入已存在的目录
  let file_content = "hello world, MoonBit!"
  let temp_dir = get_tmp_dir()
  ensure_dir(temp_dir)
  let timestamp = @async.now()
  let src_file_path = "\{temp_dir}/mv_into_src_\{timestamp}.txt"
  @fs.write_file(src_file_path, file_content, create_mode=CreateOrTruncate)
  // 创建目标目录
  let dest_dir = "\{temp_dir}/mv_into_dest_\{timestamp}"
  ensure_dir(dest_dir)
  // mv 到已存在的目录中，文件应被移入目录内部
  mv(src_file_path, dest_dir)
  let dest_file_path = "\{dest_dir}/mv_into_src_\{timestamp}.txt"
  guard @fs.exists(dest_file_path) else {
    raise fail("目标文件不存在：\{dest_file_path}")
  }
  let dest_file_content = @fs.read_file(dest_file_path).text()
  guard dest_file_content == file_content else {
    raise fail("move 失败：文件内容不一致")
  }
  // 清理
  @fs.rmdir(dest_dir, recursive=true)
}

///|
async test "move dir" {
  let (src_root_dir, src_dir_and_files) = generate_tmp_dir_and_files(
    tag="move_dir",
  )
  let dest_path = src_root_dir
    .join_path("../")
    .join_path("dest_\{@async.now()}")
  // 移动
  mv(src_root_dir, dest_path)
  let dest_dir_and_files = get_all_sub_dir_or_file_path(
    dest_path,
    include_root=true,
  )
  debug_inspect(
    src_dir_and_files.remove_prefix(src_root_dir),
    content=to_repr(dest_dir_and_files.remove_prefix(dest_path)).to_string(),
  )
  // 删除临时文件
  @fs.rmdir(dest_path, recursive=true)
}

// #borrow(path)

///|
#borrow(path)
extern "C" fn c_symlink_status(path : Bytes) -> Int = "symlink_status"

///|
pub enum SymlinkStatus {
  SymlinkNone = 0 // 不存在（路径都没有）
  SymlinkBroken = 1 // 软链接存在，但目标失效
  SymlinkOk = 2 // 软链接存在且目标有效
} derive(Debug)

///|
pub fn symlink_status(symlink_file_path : String) -> SymlinkStatus {
  let path = @ffi.string_to_c_bytes(symlink_file_path)
  match c_symlink_status(path) {
    0 => SymlinkNone
    1 => SymlinkBroken
    2 => SymlinkOk
    _ => SymlinkNone
  }
}

///|
#borrow(path)
extern "C" fn c_readlink_target(path : Bytes) -> Bytes = "readlink_target"

///|
/// 读取软连接的目标路径，如果不是软连接或读取失败返回 None
pub fn readlink_target(path : String) -> String? {
  let c_path = @ffi.string_to_c_bytes(path)
  let result = c_readlink_target(c_path)
  if result.length() == 0 {
    return None
  }
  Some(@utf8.decode_lossy(result))
}

///|
async test "symlink_status" {
  let temp_dir = get_tmp_dir()
  ensure_dir(temp_dir)
  let timestamp = @async.now()
  let test_dir = "\{temp_dir}/symlink_test_\{timestamp}"
  ensure_dir(test_dir)

  // 创建目标文件
  let target_file = "\{test_dir}/target.txt"
  @fs.write_file(target_file, "hello", create_mode=CreateOrTruncate)

  // 创建有效软连接（指向存在的文件）
  let valid_symlink = "\{test_dir}/valid_link"
  let _ = @process.run("ln", ["-s", target_file, valid_symlink])

  // 创建失效软连接（指向不存在的文件）
  let broken_symlink = "\{test_dir}/broken_link"
  let _ = @process.run("ln", [
    "-s",
    "\{test_dir}/nonexistent.txt",
    broken_symlink,
  ])

  // 测试三种状态
  debug_inspect(
    symlink_status(valid_symlink),
    content=@debug.to_string(SymlinkOk),
  )
  debug_inspect(
    symlink_status(broken_symlink),
    content=@debug.to_string(SymlinkBroken),
  )
  debug_inspect(
    symlink_status("\{test_dir}/no_such_path"),
    content=@debug.to_string(SymlinkNone),
  )

  // 清理
  @fs.rmdir(test_dir, recursive=true)
}

///|
async test "readlink_target" {
  let temp_dir = get_tmp_dir()
  ensure_dir(temp_dir)
  let timestamp = @async.now()
  let test_dir = "\{temp_dir}/readlink_test_\{timestamp}"
  ensure_dir(test_dir)

  // 创建目标文件
  let target_file = "\{test_dir}/debug.sh"
  @fs.write_file(target_file, "echo hello", create_mode=CreateOrTruncate)

  // 创建软连接指向目标文件
  let symlink_path = "\{test_dir}/f_node"
  let _ = @process.run("ln", ["-s", target_file, symlink_path])

  // 验证软连接返回正确的目标路径
  debug_inspect(
    readlink_target(symlink_path),
    content=@debug.to_string(Some(target_file)),
  )

  // 验证非软连接文件返回 None
  guard readlink_target(target_file) is None

  // 清理
  @fs.rmdir(test_dir, recursive=true)
}

///|
pub async fn remove_if_exists(file_path : String) -> Unit {
  if @fs.exists(file_path) {
    match @fs.kind(file_path) {
      Directory => @fs.rmdir(file_path, recursive=true)
      _ => @fs.remove(file_path)
    }
  } else {
    // 软连接
    match symlink_status(file_path) {
      SymlinkBroken | SymlinkOk => @fs.remove(file_path)
      _ => ()
    }
  }
}
