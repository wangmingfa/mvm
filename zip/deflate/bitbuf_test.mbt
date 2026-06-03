///|
test "bit reader - read single bits" {
  let reader = BitReader::new(b"\xFF")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
  inspect(reader.read_bits(1), content="1")
}

///|
test "bit reader - read multiple bits" {
  let reader = BitReader::new(b"\xAB")
  inspect(reader.read_bits(4), content="11")
  inspect(reader.read_bits(4), content="10")
}

///|
test "bit reader - read across bytes" {
  let reader = BitReader::new(b"\x12\x34")
  inspect(reader.read_bits(8), content="18")
  inspect(reader.read_bits(8), content="52")
}

///|
test "bit reader - peek bits" {
  let reader = BitReader::new(b"\xFF")
  inspect(reader.peek_bits(4), content="15")
  inspect(reader.peek_bits(4), content="15")
  inspect(reader.read_bits(4), content="15")
}

///|
test "bit reader - skip bits" {
  let reader = BitReader::new(b"\xFF")
  reader.skip_bits(4)
  inspect(reader.read_bits(4), content="15")
}

///|
test "bit reader - align to byte" {
  let reader = BitReader::new(b"\xFF\xAA")
  ignore(reader.read_bits(3))
  reader.align_to_byte()
  inspect(reader.read_bits(8), content="170")
}

///|
test "bit writer - write single bits" {
  let writer = BitWriter::new()
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  writer.write_bits(1U, 1)
  let result = writer.to_bytes()
  assert_eq(result.length(), 1)
  assert_eq(result[0].to_uint(), 0xFFU)
}

///|
test "bit writer - write multiple bits" {
  let writer = BitWriter::new()
  writer.write_bits(11U, 4)
  writer.write_bits(10U, 4)
  let result = writer.to_bytes()
  assert_eq(result.length(), 1)
  assert_eq(result[0].to_uint(), 0xABU)
}

///|
test "bit writer - write across bytes" {
  let writer = BitWriter::new()
  writer.write_bits(18U, 8)
  writer.write_bits(52U, 8)
  let result = writer.to_bytes()
  assert_eq(result.length(), 2)
  assert_eq(result[0].to_uint(), 18U)
  assert_eq(result[1].to_uint(), 52U)
}

///|
test "bit writer - align to byte" {
  let writer = BitWriter::new()
  writer.write_bits(5U, 3)
  writer.align_to_byte()
  writer.write_bits(170U, 8)
  let result = writer.to_bytes()
  inspect(result.length(), content="2")
}

///|
test "bit reader/writer - roundtrip" {
  let writer = BitWriter::new()
  writer.write_bits(123U, 8)
  writer.write_bits(456U, 12)
  writer.write_bits(789U, 10)
  let data = writer.to_bytes()

  let reader = BitReader::new(data)
  inspect(reader.read_bits(8), content="123")
  inspect(reader.read_bits(12), content="456")
  inspect(reader.read_bits(10), content="789")
}
