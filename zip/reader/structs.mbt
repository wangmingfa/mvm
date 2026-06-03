///|
pub struct ZipFileEntry {
  filename : String
  compressed_size : UInt64
  uncompressed_size : UInt64
  crc32 : UInt
  compression_method : UInt
  local_header_offset : UInt64
  encrypted : Bool
}

///|
pub struct ZipArchive {
  entries : Array[ZipFileEntry]
  comment : String
}

///|
pub fn ZipArchive::new() -> ZipArchive {
  { entries: [], comment: "" }
}

///|
pub let local_file_header_signature = 0x04034B50U

///|
pub let central_dir_signature = 0x02014B50U

///|
pub let end_of_central_dir_signature = 0x06054B50U

///|
pub let zip64_end_of_central_dir_signature = 0x06064B50U

///|
pub let zip64_end_of_central_dir_locator_signature = 0x07064B50U

///|
pub let zip64_extended_information_header = 0x0001U

///|
pub let compression_stored = 0U

///|
pub let compression_deflated = 8U
