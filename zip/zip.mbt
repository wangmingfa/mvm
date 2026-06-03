///|
pub fn unzip(
  file_path : String,
  output_dir : String,
  on_progress? : (Float) -> Unit,
  password? : String,
) -> Bool {
  let on_progress = if on_progress is Some(on_progress) {
    on_progress
  } else {
    _ => ()
  }

  try {
    let zip_data = @fs.read_file_to_bytes(file_path)
    let archive = match @reader.read_zip(zip_data) {
      Ok(arc) => arc
      Err(_) => return false
    }
    let files = if password is Some(pwd) {
      match @reader.extract_all(archive, zip_data, password=pwd) {
        Ok(f) => f
        Err(_) => return false
      }
    } else {
      match @reader.extract_all(archive, zip_data) {
        Ok(f) => f
        Err(_) => return false
      }
    }

    let total = files.length()
    let mut count = 0

    for filename, data in files {
      let path = @fs_ext.join_paths([output_dir, filename])
      let dir = match @fs_ext.get_parent_dir(path) {
        Some(d) => d
        None => return false
      }
      if !@fs.path_exists(dir) {
        @fs.create_dir(dir)
      }
      @fs.write_bytes_to_file(path, data)

      count = count + 1
      let progress = Float::from_int(count) / Float::from_int(total) * 100.0
      on_progress(progress)
    }

    true
  } catch {
    _ => false
  }
}

///|
pub fn zip(dir : String, zip_file_path : String, password? : String) -> Bool {
  try {
    let writer = @writer.ZipWriter::new()

    let entries = @fs.read_dir(dir)
    for entry in entries {
      let path = @fs_ext.join_paths([dir, entry])
      if @fs.is_file(path) {
        let data = @fs.read_file_to_bytes(path)
        if password is Some(pwd) {
          writer.add_file(entry, data, 6, password=pwd)
        } else {
          writer.add_file(entry, data, 6)
        }
      }
    }

    let zip_data = writer.finalize()
    @fs.write_bytes_to_file(zip_file_path, zip_data)

    true
  } catch {
    _ => false
  }
}

///|
test "unzip" {
  let dir_name = "unzip\{@env.now()}"
  let temp_dir = @test.get_temp_dir(sub_dir=dir_name)
  let mut first_file_name = ""
  try {
    if !@fs.path_exists(temp_dir) {
      @fs.create_dir(temp_dir)
    }
    for i in 1..<=10 {
      let content = "文件\{i}"
      let file_name = "test\{i}.txt"
      if first_file_name.is_blank() {
        first_file_name = file_name
      }
      let sub_dir = if i > 5 { "dir" } else { "" }
      let path = @fs_ext.join_paths([temp_dir, sub_dir, file_name])
      let dir = match @fs_ext.get_parent_dir(path) {
        Some(d) => d
        None => ""
      }
      if !@fs.path_exists(dir) {
        @fs.create_dir(dir)
      }
      @fs.write_string_to_file(path, content)
    }
    let zip_file = @fs_ext.join_paths([temp_dir, "test.zip"])
    let _ = zip(temp_dir, zip_file)
    let success = unzip(zip_file, temp_dir, on_progress=progress => {
      println("解压进度 \{progress}")
    })
    inspect(
      success,
      content=(
        #|true
      ),
    )
    inspect(
      @fs.path_exists(@fs_ext.join_paths([temp_dir, first_file_name])),
      content="true",
    )
  } catch {
    e => raise e
  }
  for file in @fs.read_dir(temp_dir) {
    let path = @fs_ext.join_paths([temp_dir, file])
    if @fs.is_dir(path) {
      for subfile in @fs.read_dir(path) {
        @fs.remove_file(@fs_ext.join_paths([path, subfile]))
      }
      @fs.remove_dir(path)
    } else {
      @fs.remove_file(path)
    }
  }
  @fs.remove_dir(temp_dir)
}

///|
test "encrypted zip" {
  let temp_dir = @test.get_temp_dir(sub_dir="encrypted_zip_test")
  try {
    if !@fs.path_exists(temp_dir) {
      @fs.create_dir(temp_dir)
    }

    let test_file = @fs_ext.join_paths([temp_dir, "secret.txt"])
    @fs.write_string_to_file(test_file, "This is encrypted content")

    let zip_file = @fs_ext.join_paths([temp_dir, "encrypted.zip"])
    let writer = @writer.ZipWriter::new()
    let data = @fs.read_file_to_bytes(test_file)
    writer.add_file("secret.txt", data, 0, password="mypassword")
    let zip_data = writer.finalize()
    @fs.write_bytes_to_file(zip_file, zip_data)

    let extract_dir = @fs_ext.join_paths([temp_dir, "extracted"])
    if !@fs.path_exists(extract_dir) {
      @fs.create_dir(extract_dir)
    }

    let extract_success = unzip(zip_file, extract_dir, password="mypassword")
    assert_true(extract_success)

    let extracted_file = @fs_ext.join_paths([extract_dir, "secret.txt"])
    assert_true(@fs.path_exists(extracted_file))

    let content = @fs.read_file_to_string(extracted_file)
    assert_eq(content, "This is encrypted content")

    @fs.remove_file(test_file)
    @fs.remove_file(zip_file)
    @fs.remove_file(extracted_file)
    @fs.remove_dir(extract_dir)
  } catch {
    e => raise e
  }
  @fs.remove_dir(temp_dir)
}
