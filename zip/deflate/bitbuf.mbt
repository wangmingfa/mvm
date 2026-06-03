///|
pub struct BitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : UInt
  mut bits_left : Int
}

///|
pub fn BitReader::new(data : Bytes) -> BitReader {
  { data, pos: 0, bit_buf: 0U, bits_left: 0 }
}

///|
pub fn BitReader::read_bits(self : BitReader, n : Int) -> UInt {
  while self.bits_left < n {
    if self.pos < self.data.length() {
      self.bit_buf = self.bit_buf |
        (self.data[self.pos].to_uint() << self.bits_left)
      self.pos = self.pos + 1
      self.bits_left = self.bits_left + 8
    } else {
      break
    }
  }
  let mask = if n >= 32 { 0xFFFFFFFFU } else { (1U << n) - 1U }
  let result = self.bit_buf & mask
  self.bit_buf = self.bit_buf >> n
  self.bits_left = self.bits_left - n
  result
}

///|
pub fn BitReader::peek_bits(self : BitReader, n : Int) -> UInt {
  let saved_buf = self.bit_buf
  let saved_left = self.bits_left
  let saved_pos = self.pos
  let result = self.read_bits(n)
  self.bit_buf = saved_buf
  self.bits_left = saved_left
  self.pos = saved_pos
  result
}

///|
pub fn BitReader::skip_bits(self : BitReader, n : Int) -> Unit {
  ignore(self.read_bits(n))
}

///|
pub fn BitReader::align_to_byte(self : BitReader) -> Unit {
  let remainder = self.bits_left % 8
  if remainder > 0 {
    self.skip_bits(remainder)
  }
}

///|
pub fn BitReader::read_byte(self : BitReader) -> UInt {
  self.read_bits(8)
}

///|
pub fn BitReader::read_bytes(self : BitReader, n : Int) -> Bytes {
  let buf = Buffer::Buffer()
  for _ in 0..<n {
    buf.write_byte(self.read_byte().to_byte())
  }
  buf.to_bytes()
}

///|
pub fn BitReader::is_empty(self : BitReader) -> Bool {
  self.pos >= self.data.length() && self.bits_left == 0
}

///|
pub fn BitReader::bytes_read(self : BitReader) -> Int {
  self.pos - (self.bits_left + 7) / 8
}
