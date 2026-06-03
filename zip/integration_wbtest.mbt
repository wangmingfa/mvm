///|
test "zip roundtrip - single file" {
  let writer = @writer.ZipWriter::new()
  let original = b"Hello, MoonBit!"
  writer.add_file("test.txt", original, 6)
  let zip_data = writer.finalize()

  let archive = @reader.read_zip(zip_data)
  match archive {
    Ok(arc) => {
      assert_true(arc.entries.length() == 1)
      assert_eq(arc.entries[0].filename, "test.txt")

      let extracted = @reader.extract_file(arc.entries[0], zip_data)
      match extracted {
        Ok(data) => {
          println("Original: \{original}")
          println("Extracted: \{data}")
          println("Original length: \{original.length()}")
          println("Extracted length: \{data.length()}")
          assert_eq(data, original)
        }
        Err(msg) => fail("Extract failed: " + msg)
      }
    }
    Err(msg) => fail("Read failed: " + msg)
  }
}

///|
test "zip roundtrip - multiple files" {
  let writer = @writer.ZipWriter::new()
  writer.add_file("file1.txt", b"First file", 6)
  writer.add_file("file2.txt", b"Second file", 6)
  writer.add_file("file3.txt", b"Third file", 6)
  let zip_data = writer.finalize()

  let archive = @reader.read_zip(zip_data)
  match archive {
    Ok(arc) => {
      assert_true(arc.entries.length() == 3)

      let extracted1 = @reader.extract_file(arc.entries[0], zip_data)
      let extracted2 = @reader.extract_file(arc.entries[1], zip_data)
      let extracted3 = @reader.extract_file(arc.entries[2], zip_data)

      match extracted1 {
        Ok(data) => assert_eq(data, b"First file")
        Err(msg) => fail("Extract failed: " + msg)
      }
      match extracted2 {
        Ok(data) => assert_eq(data, b"Second file")
        Err(msg) => fail("Extract failed: " + msg)
      }
      match extracted3 {
        Ok(data) => assert_eq(data, b"Third file")
        Err(msg) => fail("Extract failed: " + msg)
      }
    }
    Err(msg) => fail("Read failed: " + msg)
  }
}

///|
test "zip roundtrip - stored compression" {
  let writer = @writer.ZipWriter::new()
  writer.add_file("stored.txt", b"No compression", 0)
  let zip_data = writer.finalize()

  let archive = @reader.read_zip(zip_data)
  match archive {
    Ok(arc) => {
      assert_true(arc.entries.length() == 1)
      assert_eq(arc.entries[0].compression_method, @reader.compression_stored)

      let extracted = @reader.extract_file(arc.entries[0], zip_data)
      match extracted {
        Ok(data) => assert_eq(data, b"No compression")
        Err(msg) => fail("Extract failed: " + msg)
      }
    }
    Err(msg) => fail("Read failed: " + msg)
  }
}

///|
test "zip roundtrip - empty file" {
  let writer = @writer.ZipWriter::new()
  writer.add_file("empty.txt", b"", 6)
  let zip_data = writer.finalize()

  let archive = @reader.read_zip(zip_data)
  match archive {
    Ok(arc) => {
      assert_true(arc.entries.length() == 1)
      assert_eq(arc.entries[0].uncompressed_size, 0UL)

      let extracted = @reader.extract_file(arc.entries[0], zip_data)
      match extracted {
        Ok(data) => assert_eq(data, b"")
        Err(msg) => fail("Extract failed: " + msg)
      }
    }
    Err(msg) => fail("Read failed: " + msg)
  }
}

///|
test "zip roundtrip - large file" {
  let large_data = Buffer::Buffer()
  for i in 0..<10000 {
    large_data.write_bytes(@utf8.encode("Line " + i.to_string() + "\n"))
  }
  let data_bytes = large_data.to_bytes()

  let writer = @writer.ZipWriter::new()
  writer.add_file("large.txt", data_bytes, 6)
  let zip_data = writer.finalize()

  let archive = @reader.read_zip(zip_data)
  match archive {
    Ok(arc) => {
      assert_true(arc.entries.length() == 1)

      let extracted = @reader.extract_file(arc.entries[0], zip_data)
      match extracted {
        Ok(data) => assert_eq(data, data_bytes)
        Err(msg) => fail("Extract failed: " + msg)
      }
    }
    Err(msg) => fail("Read failed: " + msg)
  }
}

///|
test "deflate decompression" {
  let original = b"Hello, MoonBit!"
  let compressed = @deflate.deflate_compress(original, 6)
  println("Compressed length: \{compressed.length()}")
  println("Original length: \{original.length()}")

  let decompressed = @deflate.inflate_decompress(compressed, original.length())
  match decompressed {
    Ok(data) => {
      println("Decompressed length: \{data.length()}")
      assert_eq(data, original)
    }
    Err(msg) => fail("Decompress failed: " + msg)
  }
}

///|
test "zlib roundtrip" {
  let original = b"Test zlib compression"
  let compressed = @zlib.zlib_compress(original, 6)
  let decompressed = @zlib.zlib_decompress(compressed)
  match decompressed {
    Ok(data) => assert_eq(data, original)
    Err(msg) => fail("Decompress failed: " + msg)
  }
}

///|
test "checksum - adler32" {
  let data = b"Hello"
  let checksum = @checksum.adler32(data)
  assert_true(checksum > 0U)
}

///|
test "checksum - crc32" {
  let data = b"Hello"
  let checksum = @checksum.crc32(data)
  assert_true(checksum > 0U)
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

    let extract_success = @zip.unzip(
      zip_file,
      extract_dir,
      password="mypassword",
    )
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
