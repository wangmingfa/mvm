///|
pub fn inflate_decompress(
  data : Bytes,
  expected_size : Int,
) -> Result[Bytes, String] {
  let reader = BitReader::new(data)
  let output = Buffer::Buffer(size_hint=expected_size)

  let mut bfinal = 0U
  while bfinal == 0U {
    bfinal = reader.read_bits(1)
    let btype = reader.read_bits(2)

    if btype == 0U {
      // Stored block
      reader.align_to_byte()
      let len = reader.read_bits(16)
      let nlen = reader.read_bits(16)

      if len + nlen != 0xFFFFU {
        return Err("Invalid stored block length")
      }

      let bytes = reader.read_bytes(len.reinterpret_as_int())
      output.write_bytes(bytes)
    } else if btype == 1U {
      // Fixed Huffman
      let literal_tree = HuffmanTree::build_fixed_literal()
      let distance_tree = HuffmanTree::build_fixed_distance()

      match decode_block(reader, output, literal_tree, distance_tree) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    } else if btype == 2U {
      // Dynamic Huffman
      match decode_dynamic_block(reader, output) {
        Ok(_) => ()
        Err(msg) => return Err(msg)
      }
    } else {
      return Err("Invalid block type")
    }
  }

  Ok(output.to_bytes())
}

///|
pub fn inflate_decompress_to_buffer(data : Bytes) -> Result[Buffer, String] {
  let result = inflate_decompress(data, 0)
  match result {
    Ok(bytes) => {
      let buf = Buffer::Buffer(size_hint=bytes.length())
      buf.write_bytes(bytes)
      Ok(buf)
    }
    Err(msg) => Err(msg)
  }
}

///|
fn decode_block(
  reader : BitReader,
  output : Buffer,
  literal_tree : HuffmanTree,
  distance_tree : HuffmanTree,
) -> Result[Unit, String] {
  let mut done = false
  let output_array : FixedArray[Byte] = FixedArray::make(1024 * 1024, b'\x00')
  let mut output_pos = 0

  while !done {
    let symbol = literal_tree.decode_symbol(reader)

    if symbol < 0 {
      return Err("Invalid Huffman symbol")
    } else if symbol < 256 {
      output_array[output_pos] = symbol.to_byte()
      output_pos = output_pos + 1
    } else if symbol == 256 {
      done = true
    } else {
      let length = decode_length(reader, symbol)
      if length < 0 {
        return Err("Invalid length code")
      }

      let dist_symbol = distance_tree.decode_symbol(reader)
      if dist_symbol < 0 {
        return Err("Invalid distance symbol")
      }

      let distance = decode_distance(reader, dist_symbol)
      if distance < 0 {
        return Err("Invalid distance code")
      }

      let start = output_pos - distance
      for i in 0..<length {
        output_array[output_pos] = output_array[start + i]
        output_pos = output_pos + 1
      }
    }
  }

  for i in 0..<output_pos {
    output.write_byte(output_array[i])
  }
  Ok(())
}

///|
fn decode_length(reader : BitReader, symbol : Int) -> Int {
  if symbol <= 264 {
    symbol - 257 + 3
  } else if symbol <= 284 {
    let base = if symbol <= 268 {
      11
    } else if symbol <= 272 {
      19
    } else if symbol <= 276 {
      35
    } else if symbol <= 280 {
      67
    } else {
      131
    }
    let extra_bits = if symbol <= 268 {
      1
    } else if symbol <= 272 {
      2
    } else if symbol <= 276 {
      3
    } else if symbol <= 280 {
      4
    } else {
      5
    }
    let extra = reader.read_bits(extra_bits).reinterpret_as_int()
    let offset = if symbol <= 268 {
      (symbol - 265) * 2
    } else if symbol <= 272 {
      (symbol - 269) * 4
    } else if symbol <= 276 {
      (symbol - 273) * 8
    } else if symbol <= 280 {
      (symbol - 277) * 16
    } else {
      (symbol - 281) * 32
    }
    base + offset + extra
  } else if symbol == 285 {
    258
  } else {
    -1
  }
}

///|
fn decode_distance(reader : BitReader, symbol : Int) -> Int {
  if symbol <= 3 {
    symbol + 1
  } else if symbol <= 29 {
    let base = if symbol <= 5 {
      5
    } else if symbol <= 7 {
      9
    } else if symbol <= 9 {
      17
    } else if symbol <= 11 {
      33
    } else if symbol <= 13 {
      65
    } else if symbol <= 15 {
      129
    } else if symbol <= 17 {
      257
    } else if symbol <= 19 {
      513
    } else if symbol <= 21 {
      1025
    } else if symbol <= 23 {
      2049
    } else if symbol <= 25 {
      4097
    } else if symbol <= 27 {
      8193
    } else {
      16385
    }
    let extra_bits = if symbol <= 5 {
      1
    } else if symbol <= 7 {
      2
    } else if symbol <= 9 {
      3
    } else if symbol <= 11 {
      4
    } else if symbol <= 13 {
      5
    } else if symbol <= 15 {
      6
    } else if symbol <= 17 {
      7
    } else if symbol <= 19 {
      8
    } else if symbol <= 21 {
      9
    } else if symbol <= 23 {
      10
    } else if symbol <= 25 {
      11
    } else if symbol <= 27 {
      12
    } else {
      13
    }
    let extra = reader.read_bits(extra_bits).reinterpret_as_int()
    let offset = if symbol <= 5 {
      (symbol - 4) * 2
    } else if symbol <= 7 {
      (symbol - 6) * 4
    } else if symbol <= 9 {
      (symbol - 8) * 8
    } else if symbol <= 11 {
      (symbol - 10) * 16
    } else if symbol <= 13 {
      (symbol - 12) * 32
    } else if symbol <= 15 {
      (symbol - 14) * 64
    } else if symbol <= 17 {
      (symbol - 16) * 128
    } else if symbol <= 19 {
      (symbol - 18) * 256
    } else if symbol <= 21 {
      (symbol - 20) * 512
    } else if symbol <= 23 {
      (symbol - 22) * 1024
    } else if symbol <= 25 {
      (symbol - 24) * 2048
    } else if symbol <= 27 {
      (symbol - 26) * 4096
    } else {
      (symbol - 28) * 8192
    }
    base + offset + extra
  } else {
    -1
  }
}

///|
fn decode_dynamic_block(
  reader : BitReader,
  output : Buffer,
) -> Result[Unit, String] {
  let hlit = reader.read_bits(5).reinterpret_as_int() + 257
  let hdist = reader.read_bits(5).reinterpret_as_int() + 1
  let hclen = reader.read_bits(4).reinterpret_as_int() + 4

  // Read code length code lengths
  let code_length_order = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let code_length_lengths = Array::make(19, 0U)
  for i in 0..<hclen {
    code_length_lengths[code_length_order[i]] = reader.read_bits(3)
  }

  let code_length_tree = HuffmanTree::new(19)
  code_length_tree.build_from_lengths(code_length_lengths)

  // Read literal/length and distance code lengths
  let literal_lengths = Array::make(hlit, 0U)
  let distance_lengths = Array::make(hdist, 0U)

  let mut i = 0
  while i < hlit + hdist {
    let symbol = code_length_tree.decode_symbol(reader)
    if symbol < 0 {
      return Err("Invalid code length symbol")
    } else if symbol < 16 {
      if i < hlit {
        literal_lengths[i] = symbol.reinterpret_as_uint()
      } else {
        distance_lengths[i - hlit] = symbol.reinterpret_as_uint()
      }
      i = i + 1
    } else if symbol == 16 {
      let repeat = reader.read_bits(2).reinterpret_as_int() + 3
      let prev = if i > 0 {
        if i - 1 < hlit {
          literal_lengths[i - 1]
        } else {
          distance_lengths[i - 1 - hlit]
        }
      } else {
        0U
      }
      for _ in 0..<repeat {
        if i < hlit {
          literal_lengths[i] = prev
        } else {
          distance_lengths[i - hlit] = prev
        }
        i = i + 1
      }
    } else if symbol == 17 {
      let repeat = reader.read_bits(3).reinterpret_as_int() + 3
      for _ in 0..<repeat {
        if i < hlit {
          literal_lengths[i] = 0U
        } else {
          distance_lengths[i - hlit] = 0U
        }
        i = i + 1
      }
    } else if symbol == 18 {
      let repeat = reader.read_bits(7).reinterpret_as_int() + 11
      for _ in 0..<repeat {
        if i < hlit {
          literal_lengths[i] = 0U
        } else {
          distance_lengths[i - hlit] = 0U
        }
        i = i + 1
      }
    }
  }

  let literal_tree = HuffmanTree::new(hlit)
  literal_tree.build_from_lengths(literal_lengths)

  let distance_tree = HuffmanTree::new(hdist)
  distance_tree.build_from_lengths(distance_lengths)

  decode_block(reader, output, literal_tree, distance_tree)
}
