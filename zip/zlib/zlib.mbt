///|
pub fn zlib_compress(data : Bytes, level : Int) -> Bytes {
  let buf = Buffer::Buffer()

  // Zlib header (RFC 1950)
  // CMF byte: CM=8 (deflate), CINFO=7 (32K window)
  buf.write_byte(0x78)

  // FLG byte: FLEVEL depends on compression level
  // FCHECK is set so that CMF*256 + FLG is multiple of 31
  let flevel = if level <= 1 {
    0U
  } else if level <= 5 {
    1U
  } else if level <= 6 {
    2U
  } else {
    3U
  }
  let cmf = 0x78U
  let mut flg = flevel << 6
  let check = (cmf * 256U + flg) % 31U
  if check != 0U {
    flg = flg + (31U - check)
  }
  buf.write_byte(flg.to_byte())

  // Compressed data
  let compressed = @deflate.deflate_compress(data, level)
  buf.write_bytes(compressed)

  // Adler-32 checksum (big-endian)
  let checksum = @checksum.adler32(data)
  buf.write_byte(((checksum >> 24) & 0xFFU).to_byte())
  buf.write_byte(((checksum >> 16) & 0xFFU).to_byte())
  buf.write_byte(((checksum >> 8) & 0xFFU).to_byte())
  buf.write_byte((checksum & 0xFFU).to_byte())

  buf.to_bytes()
}

///|
pub fn zlib_decompress(data : Bytes) -> Result[Bytes, String] {
  if data.length() < 6 {
    return Err("Data too short for zlib format")
  }

  // Verify zlib header
  let cmf = data[0].to_uint()
  let flg = data[1].to_uint()

  if (cmf * 256U + flg) % 31U != 0U {
    return Err("Invalid zlib header checksum")
  }

  let cm = cmf & 0x0FU
  if cm != 8U {
    return Err("Unsupported compression method")
  }

  // Extract compressed data (skip 2-byte header, exclude 4-byte checksum)
  let compressed = data[2:data.length() - 4].to_owned()

  // Decompress
  let result = @deflate.inflate_decompress(compressed, 0)

  match result {
    Ok(decompressed) => {
      // Verify Adler-32 checksum
      let stored_checksum = (data[data.length() - 4].to_uint() << 24) |
        (data[data.length() - 3].to_uint() << 16) |
        (data[data.length() - 2].to_uint() << 8) |
        data[data.length() - 1].to_uint()
      let computed_checksum = @checksum.adler32(decompressed)

      if stored_checksum != computed_checksum {
        Err("Adler-32 checksum mismatch")
      } else {
        Ok(decompressed)
      }
    }
    Err(msg) => Err(msg)
  }
}
