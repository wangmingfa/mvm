///|
test "huffman - build fixed literal tree" {
  let tree = HuffmanTree::build_fixed_literal()
  inspect(tree.max_code_length, content="9")
  assert_eq(tree.code_lengths[0], 8U)
  assert_eq(tree.code_lengths[144], 9U)
  assert_eq(tree.code_lengths[256], 7U)
  assert_eq(tree.code_lengths[280], 8U)
}

///|
test "huffman - build fixed distance tree" {
  let tree = HuffmanTree::build_fixed_distance()
  inspect(tree.max_code_length, content="5")
  assert_eq(tree.code_lengths[0], 5U)
  assert_eq(tree.code_lengths[31], 5U)
}

///|
test "huffman - encode and decode symbol" {
  let tree = HuffmanTree::build_fixed_literal()
  let writer = BitWriter::new()

  tree.encode_symbol(writer, 65)
  tree.encode_symbol(writer, 66)
  tree.encode_symbol(writer, 256)

  let data = writer.to_bytes()
  let reader = BitReader::new(data)

  inspect(tree.decode_symbol(reader), content="65")
  inspect(tree.decode_symbol(reader), content="66")
  inspect(tree.decode_symbol(reader), content="256")
}

///|
test "huffman - roundtrip all symbols" {
  let tree = HuffmanTree::build_fixed_literal()
  let writer = BitWriter::new()

  for i in 0..<288 {
    tree.encode_symbol(writer, i)
  }

  let data = writer.to_bytes()
  let reader = BitReader::new(data)

  for i in 0..<288 {
    let decoded = tree.decode_symbol(reader)
    assert_eq(decoded, i)
  }
}
