///|
type MoonBitCallback = (Float) -> Unit

///|
type OnProgressCallback = FuncRef[(MoonBitCallback, Float) -> Unit]

///|
#borrow(zip_file_path, output_dir)
extern "C" fn unzip_to_dir_with_progress(
  zip_file_path : Bytes,
  output_dir : Bytes,
  on_progress : OnProgressCallback,
  callback : MoonBitCallback,
) -> Int = "unzip_to_dir_with_progress"

///|
pub fn unzip(
  file_path : String,
  output_dir : String,
  on_progress? : (Float) -> Unit,
) -> Bool {
  let on_progress = if on_progress is Some(on_progress) {
    on_progress
  } else {
    _ => ()
  }
  unzip_to_dir_with_progress(
    @ffi.string_to_c_bytes(file_path),
    @ffi.string_to_c_bytes(output_dir),
    fn(on_progress, progress) {
      // 取整数
      let progress = progress.floor()
      on_progress(progress)
    },
    on_progress,
  ) ==
  0
}

///|
#cfg(platform="windows")
pub async fn zip(
  dir : String,
  zip_file_path : String,
  cwd? : StringView,
) -> Bool {
  let code = @mvm_cmd.run(
    "Compress-Archive",
    ["-Path", dir, "-DestinationPath", zip_file_path],
    cwd?,
  )
  code == 0
}

///|
#cfg(not(platform="windows"))
pub async fn zip(
  dir : String,
  zip_file_path : String,
  cwd? : StringView,
) -> Bool {
  let code = @mvm_cmd.run("zip", ["-r", zip_file_path, dir], cwd?)
  code == 0
}

///|
async test "unzip" {
  let dir_name = "unzip\{@env.now()}"
  let temp_dir = @test.get_temp_dir(sub_dir=dir_name)
  println("临时目录 \{temp_dir}")
  let mut first_file_name = ""
  try {
    @fs_ext.ensure_dir(temp_dir)
    // 生成多个txt文件
    for i in 1..<=10 {
      let content = "文件\{i}"
      let file_name = "test\{i}.txt"
      if first_file_name.is_blank() {
        first_file_name = file_name
      }
      // 后面的文件放到子文件夹下
      let sub_dir = if i > 5 { "dir" } else { "" }
      @fs_ext.ensure_paths([temp_dir, sub_dir])
      let path = @fs_ext.join_paths([temp_dir, sub_dir, file_name])
      @fs.write_file(path, content, create_mode=CreateOrTruncate)
    }
    // 生成压缩文件
    let zip_file = "\{temp_dir}/test.zip"
    let _ = zip(dir_name, zip_file, cwd=@fs_ext.join_path(temp_dir, ".."))
    // 解压文件
    let success = unzip(zip_file, temp_dir, on_progress=progress => {
      println("解压进度 \{progress}")
    })
    // 判断是否解压成功
    inspect(
      success,
      content=(
        #|true
      ),
    )
    // 判断解压后的文件是否存在
    inspect(
      @fs.exists(@fs_ext.join_paths([temp_dir, dir_name, first_file_name])),
      content="true",
    )
  } catch {
    e => raise e
  }
  @fs_ext.remove_dir(temp_dir)
}
