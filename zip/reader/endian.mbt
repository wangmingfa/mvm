///|
pub fn read_le16(data : Bytes, offset : Int) -> UInt {
  data[offset].to_uint() | (data[offset + 1].to_uint() << 8)
}

///|
pub fn read_le32(data : Bytes, offset : Int) -> UInt {
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
pub fn read_le64(data : Bytes, offset : Int) -> UInt64 {
  let low = read_le32(data, offset).to_uint64()
  let high = read_le32(data, offset + 4).to_uint64()
  low | (high << 32)
}

///|
pub fn write_le16(buf : Buffer, value : UInt) -> Unit {
  buf.write_byte((value & 0xFFU).to_byte())
  buf.write_byte(((value >> 8) & 0xFFU).to_byte())
}

///|
pub fn write_le32(buf : Buffer, value : UInt) -> Unit {
  buf.write_byte((value & 0xFFU).to_byte())
  buf.write_byte(((value >> 8) & 0xFFU).to_byte())
  buf.write_byte(((value >> 16) & 0xFFU).to_byte())
  buf.write_byte(((value >> 24) & 0xFFU).to_byte())
}

///|
pub fn write_le64(buf : Buffer, value : UInt64) -> Unit {
  write_le32(buf, (value & 0xFFFFFFFFUL).to_uint())
  write_le32(buf, (value >> 32).to_uint())
}
