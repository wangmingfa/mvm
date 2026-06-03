///|
pub struct ZipWriter {
  buffer : Buffer
  entries : Array[ZipWriterEntry]
  mut offset : UInt64
}

///|
pub struct ZipWriterEntry {
  filename : String
  crc32 : UInt
  compressed_size : UInt64
  uncompressed_size : UInt64
  local_header_offset : UInt64
  compression_method : UInt
  encrypted : Bool
}

///|
pub fn ZipWriter::new() -> ZipWriter {
  { buffer: Buffer::Buffer(), entries: [], offset: 0UL }
}

///|
pub fn ZipWriter::add_file(
  self : ZipWriter,
  filename : String,
  data : Bytes,
  level : Int,
  password? : String,
) -> Unit {
  let crc = @checksum.crc32(data)
  let compression_method = if level == 0 {
    @reader.compression_stored
  } else {
    @reader.compression_deflated
  }
  let compressed = if level == 0 {
    data
  } else {
    @deflate.deflate_compress(data, level)
  }

  let encrypted_data = if password is Some(pwd) {
    let pwd_bytes = @utf8.encode(pwd)
    let header = @crypto.make_encryption_header(pwd_bytes, crc)
    let enc_data = @crypto.zip_crypto_encrypt(pwd_bytes, compressed)
    let result = Buffer::Buffer()
    result.write_bytes(header)
    result.write_bytes(enc_data)
    result.to_bytes()
  } else {
    compressed
  }

  let encrypted = password is Some(_)

  let compressed_size = encrypted_data.length().to_uint64()
  let uncompressed_size = data.length().to_uint64()

  let need_zip64 = compressed_size >= 0xFFFFFFFFUL ||
    uncompressed_size >= 0xFFFFFFFFUL ||
    self.offset >= 0xFFFFFFFFUL

  @reader.write_le32(self.buffer, @reader.local_file_header_signature)
  @reader.write_le16(self.buffer, if need_zip64 { 45U } else { 20U })
  let flags = if encrypted { 1U } else { 0U }
  @reader.write_le16(self.buffer, flags)
  @reader.write_le16(self.buffer, compression_method)
  @reader.write_le16(self.buffer, 0U)
  @reader.write_le16(self.buffer, 0U)
  @reader.write_le32(self.buffer, crc)

  let filename_bytes = @utf8.encode(filename)

  if need_zip64 {
    @reader.write_le32(self.buffer, 0xFFFFFFFFU)
    @reader.write_le32(self.buffer, 0xFFFFFFFFU)
    @reader.write_le16(
      self.buffer,
      filename_bytes.length().reinterpret_as_uint(),
    )
    @reader.write_le16(self.buffer, 20U)
    self.buffer.write_bytes(filename_bytes)
    @reader.write_le16(self.buffer, @reader.zip64_extended_information_header)
    @reader.write_le16(self.buffer, 16U)
    @reader.write_le64(self.buffer, uncompressed_size)
    @reader.write_le64(self.buffer, compressed_size)
  } else {
    @reader.write_le32(self.buffer, compressed_size.to_uint())
    @reader.write_le32(self.buffer, uncompressed_size.to_uint())
    @reader.write_le16(
      self.buffer,
      filename_bytes.length().reinterpret_as_uint(),
    )
    @reader.write_le16(self.buffer, 0U)
    self.buffer.write_bytes(filename_bytes)
  }

  self.buffer.write_bytes(encrypted_data)

  self.entries.push({
    filename,
    crc32: crc,
    compressed_size,
    uncompressed_size,
    local_header_offset: self.offset,
    compression_method,
    encrypted,
  })

  self.offset = self.offset +
    30UL +
    filename_bytes.length().to_uint64() +
    compressed_size +
    (if need_zip64 { 24UL } else { 0UL })
}

///|
pub fn ZipWriter::finalize(self : ZipWriter) -> Bytes {
  let cd_offset = self.offset

  for entry in self.entries {
    @reader.write_le32(self.buffer, @reader.central_dir_signature)
    @reader.write_le16(self.buffer, 20U)
    @reader.write_le16(
      self.buffer,
      if entry.compressed_size >= 0xFFFFFFFFUL ||
        entry.uncompressed_size >= 0xFFFFFFFFUL ||
        entry.local_header_offset >= 0xFFFFFFFFUL {
        45U
      } else {
        20U
      },
    )
    let flags = if entry.encrypted { 1U } else { 0U }
    @reader.write_le16(self.buffer, flags)
    @reader.write_le16(self.buffer, entry.compression_method)
    @reader.write_le16(self.buffer, 0U)
    @reader.write_le16(self.buffer, 0U)
    @reader.write_le32(self.buffer, entry.crc32)

    let filename_bytes = @utf8.encode(entry.filename)

    if entry.compressed_size >= 0xFFFFFFFFUL ||
      entry.uncompressed_size >= 0xFFFFFFFFUL ||
      entry.local_header_offset >= 0xFFFFFFFFUL {
      @reader.write_le32(self.buffer, 0xFFFFFFFFU)
      @reader.write_le32(self.buffer, 0xFFFFFFFFU)
      @reader.write_le16(
        self.buffer,
        filename_bytes.length().reinterpret_as_uint(),
      )
      @reader.write_le16(self.buffer, 28U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le32(self.buffer, 0U)
      @reader.write_le32(self.buffer, 0xFFFFFFFFU)
      self.buffer.write_bytes(filename_bytes)
      @reader.write_le16(self.buffer, @reader.zip64_extended_information_header)
      @reader.write_le16(self.buffer, 24U)
      @reader.write_le64(self.buffer, entry.uncompressed_size)
      @reader.write_le64(self.buffer, entry.compressed_size)
      @reader.write_le64(self.buffer, entry.local_header_offset)
      self.offset = self.offset +
        46UL +
        filename_bytes.length().to_uint64() +
        28UL
    } else {
      @reader.write_le32(self.buffer, entry.compressed_size.to_uint())
      @reader.write_le32(self.buffer, entry.uncompressed_size.to_uint())
      @reader.write_le16(
        self.buffer,
        filename_bytes.length().reinterpret_as_uint(),
      )
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le16(self.buffer, 0U)
      @reader.write_le32(self.buffer, 0U)
      @reader.write_le32(self.buffer, entry.local_header_offset.to_uint())
      self.buffer.write_bytes(filename_bytes)
      self.offset = self.offset + 46UL + filename_bytes.length().to_uint64()
    }
  }

  let cd_size = self.offset - cd_offset

  if cd_size >= 0xFFFFFFFFUL ||
    cd_offset >= 0xFFFFFFFFUL ||
    self.entries.length() >= 0xFFFF {
    let zip64_eocd_offset = self.offset
    @reader.write_le32(self.buffer, @reader.zip64_end_of_central_dir_signature)
    @reader.write_le64(self.buffer, 44UL)
    @reader.write_le16(self.buffer, 45U)
    @reader.write_le16(self.buffer, 45U)
    @reader.write_le32(self.buffer, 0U)
    @reader.write_le32(self.buffer, 0U)
    @reader.write_le64(self.buffer, self.entries.length().to_uint64())
    @reader.write_le64(self.buffer, self.entries.length().to_uint64())
    @reader.write_le64(self.buffer, cd_size)
    @reader.write_le64(self.buffer, cd_offset)

    @reader.write_le32(
      self.buffer,
      @reader.zip64_end_of_central_dir_locator_signature,
    )
    @reader.write_le32(self.buffer, 0U)
    @reader.write_le64(self.buffer, zip64_eocd_offset)
    @reader.write_le32(self.buffer, 1U)
  }

  @reader.write_le32(self.buffer, @reader.end_of_central_dir_signature)
  @reader.write_le16(self.buffer, 0U)
  @reader.write_le16(self.buffer, 0U)
  @reader.write_le16(
    self.buffer,
    if self.entries.length() >= 0xFFFF {
      0xFFFFU
    } else {
      self.entries.length().reinterpret_as_uint()
    },
  )
  @reader.write_le16(
    self.buffer,
    if self.entries.length() >= 0xFFFF {
      0xFFFFU
    } else {
      self.entries.length().reinterpret_as_uint()
    },
  )
  @reader.write_le32(
    self.buffer,
    if cd_size >= 0xFFFFFFFFUL {
      0xFFFFFFFFU
    } else {
      cd_size.to_uint()
    },
  )
  @reader.write_le32(
    self.buffer,
    if cd_offset >= 0xFFFFFFFFUL {
      0xFFFFFFFFU
    } else {
      cd_offset.to_uint()
    },
  )
  @reader.write_le16(self.buffer, 0U)

  self.buffer.to_bytes()
}
