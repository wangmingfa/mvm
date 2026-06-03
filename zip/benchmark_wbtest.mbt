///|
test "benchmark compression speed" {
  let data_size = 100000
  let test_data = Buffer::Buffer(size_hint=data_size)
  for i in 0..<data_size {
    test_data.write_byte((i % 256).to_byte())
  }
  let data = test_data.to_bytes()

  let start = @env.now()
  let compressed = @deflate.deflate_compress(data, 6)
  let end = @env.now()

  let duration = end - start
  let speed = Float::from_int(data.length()) /
    Float::from_uint64(duration) /
    1024.0

  println("Data size: \{data.length()} bytes")
  println("Compressed size: \{compressed.length()} bytes")
  println(
    "Ratio: \{Float::from_int(compressed.length()) / Float::from_int(data.length()) * 100.0}%",
  )
  println("Time: \{duration} ms")
  println("Speed: \{speed} KB/s")

  assert_true(compressed.length() < data.length())
}

///|
test "benchmark decompression speed" {
  let data_size = 100000
  let test_data = Buffer::Buffer(size_hint=data_size)
  for i in 0..<data_size {
    test_data.write_byte((i % 256).to_byte())
  }
  let data = test_data.to_bytes()

  let compressed = @deflate.deflate_compress(data, 6)

  let start = @env.now()
  let decompressed = @deflate.inflate_decompress(compressed, data.length())
  let end = @env.now()

  match decompressed {
    Ok(result) => {
      let duration = end - start
      let speed = Float::from_int(result.length()) /
        Float::from_uint64(duration) /
        1024.0

      println("Compressed size: \{compressed.length()} bytes")
      println("Decompressed size: \{result.length()} bytes")
      println("Time: \{duration} ms")
      println("Speed: \{speed} KB/s")

      assert_eq(result, data)
    }
    Err(msg) => fail("Decompression failed: " + msg)
  }
}

///|
test "benchmark different compression levels" {
  let data_size = 50000
  let test_data = Buffer::Buffer(size_hint=data_size)
  for i in 0..<data_size {
    test_data.write_byte((i % 256).to_byte())
  }
  let data = test_data.to_bytes()

  println("\nCompression level comparison:")
  println("Level | Size | Ratio | Time (ms) | Speed (KB/s)")
  println("------|------|-------|-----------|-------------")

  for level in [0, 1, 3, 6, 9] {
    let start = @env.now()
    let compressed = @deflate.deflate_compress(data, level)
    let end = @env.now()

    let duration = end - start
    let ratio = Float::from_int(compressed.length()) /
      Float::from_int(data.length()) *
      100.0
    let speed = Float::from_int(data.length()) /
      Float::from_uint64(duration) /
      1024.0

    println(
      "\{level}     | \{compressed.length()} | \{ratio}% | \{duration} | \{speed}",
    )
  }
}

///|
test "benchmark zip operations" {
  let temp_dir = @test.get_temp_dir(sub_dir="benchmark_zip")
  try {
    if !@fs.path_exists(temp_dir) {
      @fs.create_dir(temp_dir)
    }

    let file_size = 50000
    let test_data = Buffer::Buffer(size_hint=file_size)
    for i in 0..<file_size {
      test_data.write_byte((i % 256).to_byte())
    }
    let data = test_data.to_bytes()

    let test_file = @fs_ext.join_paths([temp_dir, "benchmark.txt"])
    @fs.write_bytes_to_file(test_file, data)

    let zip_file = @fs_ext.join_paths([temp_dir, "benchmark.zip"])

    let start = @env.now()
    let success = @zip.zip(temp_dir, zip_file)
    let end = @env.now()

    if !success {
      println("Failed to create ZIP")
      @fs.remove_file(test_file)
      return
    }

    let create_duration = end - start
    let create_speed = Float::from_int(data.length()) /
      Float::from_uint64(create_duration) /
      1024.0

    let zip_data = @fs.read_file_to_bytes(zip_file)
    let zip_size = zip_data.length()

    println("\nZIP creation:")
    println("Original size: \{data.length()} bytes")
    println("ZIP size: \{zip_size} bytes")
    println(
      "Ratio: \{Float::from_int(zip_size) / Float::from_int(data.length()) * 100.0}%",
    )
    println("Time: \{create_duration} ms")
    println("Speed: \{create_speed} KB/s")

    let extract_dir = @fs_ext.join_paths([temp_dir, "extracted"])
    if !@fs.path_exists(extract_dir) {
      @fs.create_dir(extract_dir)
    }

    let start_extract = @env.now()
    let extract_success = @zip.unzip(zip_file, extract_dir, on_progress=_ => ())
    let end_extract = @env.now()

    if !extract_success {
      println("Failed to extract ZIP")
      @fs.remove_file(test_file)
      @fs.remove_file(zip_file)
      @fs.remove_dir(extract_dir)
      return
    }

    let extract_duration = end_extract - start_extract
    let extract_speed = Float::from_int(data.length()) /
      Float::from_uint64(extract_duration) /
      1024.0

    println("\nZIP extraction:")
    println("Time: \{extract_duration} ms")
    println("Speed: \{extract_speed} KB/s")

    assert_true(success)
    assert_true(extract_success)
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
