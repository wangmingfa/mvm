///|
pub struct BitWriter {
  buf : Buffer
  mut bit_buf : UInt
  mut bits_left : Int
}

///|
pub fn BitWriter::new() -> BitWriter {
  { buf: Buffer::Buffer(), bit_buf: 0U, bits_left: 0 }
}

///|
pub fn BitWriter::write_bits(self : BitWriter, value : UInt, n : Int) -> Unit {
  self.bit_buf = self.bit_buf | (value << self.bits_left)
  self.bits_left = self.bits_left + n
  while self.bits_left >= 8 {
    self.buf.write_byte((self.bit_buf & 0xFFU).to_byte())
    self.bit_buf = self.bit_buf >> 8
    self.bits_left = self.bits_left - 8
  }
}

///|
pub fn BitWriter::flush(self : BitWriter) -> Unit {
  if self.bits_left > 0 {
    self.buf.write_byte(self.bit_buf.to_byte())
    self.bit_buf = 0U
    self.bits_left = 0
  }
}

///|
pub fn BitWriter::align_to_byte(self : BitWriter) -> Unit {
  if self.bits_left > 0 {
    let padding = 8 - self.bits_left
    self.write_bits(0U, padding)
  }
}

///|
pub fn BitWriter::write_byte(self : BitWriter, byte : UInt) -> Unit {
  self.write_bits(byte, 8)
}

///|
pub fn BitWriter::write_bytes(self : BitWriter, data : Bytes) -> Unit {
  for byte in data {
    self.write_byte(byte.to_uint())
  }
}

///|
pub fn BitWriter::to_bytes(self : BitWriter) -> Bytes {
  self.flush()
  self.buf.to_bytes()
}

///|
pub fn BitWriter::bytes_written(self : BitWriter) -> Int {
  self.buf.length() + (self.bits_left + 7) / 8
}
