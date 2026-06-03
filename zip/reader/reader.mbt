///|
pub fn read_zip(data : Bytes) -> Result[ZipArchive, String] {
  let eocd_offset = match find_eocd(data) {
    Ok(offset) => offset
    Err(msg) => return Err(msg)
  }

  let num_entries = read_le16(data, eocd_offset + 10).reinterpret_as_int()
  let cd_size = read_le32(data, eocd_offset + 12)
  let cd_offset = read_le32(data, eocd_offset + 16)
  let comment_length = read_le16(data, eocd_offset + 20).reinterpret_as_int()

  let mut actual_cd_offset : UInt64 = cd_offset.to_uint64()
  let mut actual_cd_size : UInt64 = cd_size.to_uint64()
  let mut actual_num_entries : UInt64 = num_entries.to_uint64()

  if cd_offset == 0xFFFFFFFFU || num_entries == 0xFFFF {
    let locator_offset = eocd_offset - 20
    if read_le32(data, locator_offset) ==
      zip64_end_of_central_dir_locator_signature {
      let zip64_eocd_offset = read_le64(data, locator_offset + 8)

      if read_le32(data, UInt64::to_int(zip64_eocd_offset)) ==
        zip64_end_of_central_dir_signature {
        actual_num_entries = read_le64(
          data,
          UInt64::to_int(zip64_eocd_offset + 32UL),
        )
        actual_cd_size = read_le64(
          data,
          UInt64::to_int(zip64_eocd_offset + 40UL),
        )
        ignore(actual_cd_size)
        actual_cd_offset = read_le64(
          data,
          UInt64::to_int(zip64_eocd_offset + 48UL),
        )
      }
    }
  }

  let mut offset = UInt64::to_int(actual_cd_offset)
  let entries : Array[ZipFileEntry] = []

  for _ in 0..<UInt64::to_int(actual_num_entries) {
    if read_le32(data, offset) != central_dir_signature {
      return Err("Invalid central directory signature")
    }

    let general_flags = read_le16(data, offset + 8)
    let encrypted = (general_flags & 1U) != 0U
    let compression_method = read_le16(data, offset + 10)
    let crc32 = read_le32(data, offset + 16)
    let mut compressed_size = read_le32(data, offset + 20).to_uint64()
    let mut uncompressed_size = read_le32(data, offset + 24).to_uint64()
    let filename_length = read_le16(data, offset + 28).reinterpret_as_int()
    let extra_length = read_le16(data, offset + 30).reinterpret_as_int()
    let comment_length = read_le16(data, offset + 32).reinterpret_as_int()
    let mut local_header_offset = read_le32(data, offset + 42).to_uint64()

    let filename_bytes = data[offset + 46:offset + 46 + filename_length].to_owned()
    let filename = @utf8.decode_lossy(filename_bytes)

    let extra_start = offset + 46 + filename_length
    if extra_length > 0 {
      let mut extra_offset = extra_start
      while extra_offset + 4 <= extra_start + extra_length {
        let header_id = read_le16(data, extra_offset)
        let data_size = read_le16(data, extra_offset + 2).reinterpret_as_int()
        extra_offset = extra_offset + 4

        if header_id == zip64_extended_information_header &&
          extra_offset + data_size <= extra_start + extra_length {
          let zip64_offset = extra_offset
          if uncompressed_size == 0xFFFFFFFFUL &&
            zip64_offset + 8 <= extra_offset + data_size {
            uncompressed_size = read_le64(data, zip64_offset)
            compressed_size = read_le64(data, zip64_offset)
            local_header_offset = read_le64(data, zip64_offset)
          }
        }

        extra_offset = extra_offset + data_size
      }
    }

    entries.push({
      filename,
      compressed_size,
      uncompressed_size,
      crc32,
      compression_method,
      local_header_offset,
      encrypted,
    })

    offset = offset + 46 + filename_length + extra_length + comment_length
  }

  let comment = if comment_length > 0 {
    let comment_bytes = data[eocd_offset + 22:eocd_offset + 22 + comment_length].to_owned()
    @utf8.decode_lossy(comment_bytes)
  } else {
    ""
  }

  Ok({ entries, comment })
}

///|
fn find_eocd(data : Bytes) -> Result[Int, String] {
  // Search backwards for EOCD signature
  let min_offset = if data.length() >= 22 { data.length() - 22 } else { 0 }
  let max_search = if data.length() >= 65557 {
    data.length() - 65557
  } else {
    0
  }

  for i = min_offset; i >= max_search; i = i - 1 {
    if read_le32(data, i) == end_of_central_dir_signature {
      return Ok(i)
    }
  }

  Err("End of central directory record not found")
}

///|
pub fn extract_file(
  entry : ZipFileEntry,
  data : Bytes,
  password? : String,
) -> Result[Bytes, String] {
  let offset = UInt64::to_int(entry.local_header_offset)

  if read_le32(data, offset) != local_file_header_signature {
    return Err("Invalid local file header signature")
  }

  let filename_length = read_le16(data, offset + 26).reinterpret_as_int()
  let extra_length = read_le16(data, offset + 28).reinterpret_as_int()

  let data_offset = offset + 30 + filename_length + extra_length

  let mut compressed_data = data[data_offset:data_offset +
  UInt64::to_int(entry.compressed_size)].to_owned()

  if entry.encrypted {
    if password is None {
      return Err("File is encrypted but no password provided")
    }
    let pwd = password.unwrap()
    let pwd_bytes = @utf8.encode(pwd)

    if compressed_data.length() < 12 {
      return Err("Encrypted data too short")
    }

    if !@crypto.verify_encryption_header(
        compressed_data[0:12].to_owned(),
        pwd_bytes,
        entry.crc32,
      ) {
      return Err("Invalid password or corrupted file")
    }

    compressed_data = @crypto.zip_crypto_decrypt(
      pwd_bytes,
      compressed_data[12:].to_owned(),
    )
  }

  let decompressed = if entry.compression_method == compression_stored {
    compressed_data
  } else if entry.compression_method == compression_deflated {
    match
      @deflate.inflate_decompress(
        compressed_data,
        UInt64::to_int(entry.uncompressed_size),
      ) {
      Ok(d) => d
      Err(msg) => return Err("Decompression failed: " + msg)
    }
  } else {
    return Err("Unsupported compression method")
  }

  let computed_crc = @checksum.crc32(decompressed)

  if computed_crc != entry.crc32 {
    return Err("CRC-32 mismatch")
  }

  Ok(decompressed)
}

///|
pub fn extract_all(
  archive : ZipArchive,
  data : Bytes,
  password? : String,
) -> Result[Map[String, Bytes], String] {
  let files = {}

  for entry in archive.entries {
    let extracted = if password is Some(pwd) {
      match extract_file(entry, data, password=pwd) {
        Ok(d) => d
        Err(msg) => return Err(msg)
      }
    } else {
      match extract_file(entry, data) {
        Ok(d) => d
        Err(msg) => return Err(msg)
      }
    }
    files[entry.filename] = extracted
  }

  Ok(files)
}
