///|
pub fn deflate_compress(data : Bytes, level : Int) -> Bytes {
  let writer = BitWriter::new()

  // Single block with BFINAL=1
  writer.write_bits(1U, 1)

  if level == 0 {
    // Stored block (no compression)
    writer.write_bits(0U, 2)
    writer.flush()

    let len = data.length()
    writer.write_bits(len.reinterpret_as_uint() & 0xFFFF, 16)
    writer.write_bits(0xFFFFU - (len.reinterpret_as_uint() & 0xFFFF), 16)
    writer.flush()

    writer.write_bytes(data)
  } else {
    // Fixed Huffman block
    writer.write_bits(1U, 2)

    let literal_tree = HuffmanTree::build_fixed_literal()
    let distance_tree = HuffmanTree::build_fixed_distance()

    if level == 1 {
      // Fast compression - no LZ77, just literals
      let mut i = 0
      while i < data.length() {
        let byte = data[i].to_uint()
        literal_tree.encode_symbol(writer, byte.reinterpret_as_int())
        i = i + 1
      }
    } else {
      // LZ77 compression
      let matches = lz77_compress(data, level)
      let mut i = 0
      while i < matches.length() {
        let entry = matches[i]
        if entry.length == 0 {
          // Literal byte
          literal_tree.encode_symbol(writer, entry.literal.reinterpret_as_int())
        } else {
          // Length/distance pair
          encode_length(writer, literal_tree, entry.length)
          encode_distance(writer, distance_tree, entry.distance)
        }
        i = i + 1
      }
    }

    // End of block marker
    literal_tree.encode_symbol(writer, 256)
  }

  writer.to_bytes()
}

///|
priv struct LZ77Match {
  literal : UInt
  length : Int
  distance : Int
}

///|
fn lz77_compress(data : Bytes, level : Int) -> Array[LZ77Match] {
  let matches = []
  let mut pos = 0

  // Hash table for finding matches
  let hash_table = Array::make(32768, -1)

  let max_chain = if level <= 3 { 4 } else if level <= 6 { 16 } else { 64 }

  while pos < data.length() {
    if pos + 3 >= data.length() {
      // Near end - emit literals
      matches.push({ literal: data[pos].to_uint(), length: 0, distance: 0 })
      pos = pos + 1
    } else {
      // Try to find a match
      let hash = (
          (data[pos].to_uint() << 16) |
          (data[pos + 1].to_uint() << 8) |
          data[pos + 2].to_uint()
        ) %
        32768
      let mut best_length = 0
      let mut best_distance = 0
      let mut chain_pos = hash_table[hash.reinterpret_as_int()]
      let mut chain_count = 0

      while chain_pos >= 0 && chain_count < max_chain {
        let distance = pos - chain_pos
        if distance > 0 && distance <= 32768 {
          // Check match length
          let mut length = 0
          while pos + length < data.length() &&
                chain_pos + length < pos &&
                data[pos + length] == data[chain_pos + length] &&
                length < 258 {
            length = length + 1
          }
          if length > best_length && length >= 3 {
            best_length = length
            best_distance = distance
          }
        }
        // Move to previous position with same hash
        let prev_hash = (
            (data[chain_pos].to_uint() << 16) |
            (data[chain_pos + 1].to_uint() << 8) |
            data[chain_pos + 2].to_uint()
          ) %
          32768
        if prev_hash != hash {
          break
        }
        chain_pos = chain_pos - 1
        chain_count = chain_count + 1
      }

      if best_length >= 3 {
        // Emit length/distance pair
        matches.push({
          literal: 0U,
          length: best_length,
          distance: best_distance,
        })
        // Update hash table for all positions in the match
        for i in 0..<best_length {
          if pos + i + 2 < data.length() {
            let h = (
                (data[pos + i].to_uint() << 16) |
                (data[pos + i + 1].to_uint() << 8) |
                data[pos + i + 2].to_uint()
              ) %
              32768
            hash_table[h.reinterpret_as_int()] = pos + i
          }
        }
        pos = pos + best_length
      } else {
        // No good match - emit literal
        matches.push({ literal: data[pos].to_uint(), length: 0, distance: 0 })
        hash_table[hash.reinterpret_as_int()] = pos
        pos = pos + 1
      }
    }
  }

  matches
}

///|
fn encode_length(writer : BitWriter, tree : HuffmanTree, length : Int) -> Unit {
  // RFC 1951 length codes
  let (code, extra_bits, extra_value) = if length <= 10 {
    (257 + length - 3, 0, 0U)
  } else if length <= 18 {
    (265 + (length - 11) / 2, 1, ((length - 11) % 2).reinterpret_as_uint())
  } else if length <= 34 {
    (269 + (length - 19) / 4, 2, ((length - 19) % 4).reinterpret_as_uint())
  } else if length <= 66 {
    (273 + (length - 35) / 8, 3, ((length - 35) % 8).reinterpret_as_uint())
  } else if length <= 130 {
    (277 + (length - 67) / 16, 4, ((length - 67) % 16).reinterpret_as_uint())
  } else if length <= 257 {
    (281 + (length - 131) / 32, 5, ((length - 131) % 32).reinterpret_as_uint())
  } else {
    (285, 0, 0U)
  }

  tree.encode_symbol(writer, code)
  if extra_bits > 0 {
    writer.write_bits(extra_value, extra_bits)
  }
}

///|
fn encode_distance(
  writer : BitWriter,
  tree : HuffmanTree,
  distance : Int,
) -> Unit {
  // RFC 1951 distance codes
  let (code, extra_bits, extra_value) = if distance <= 4 {
    (distance - 1, 0, 0U)
  } else if distance <= 8 {
    (4 + (distance - 5) / 2, 1, ((distance - 5) % 2).reinterpret_as_uint())
  } else if distance <= 16 {
    (6 + (distance - 9) / 4, 2, ((distance - 9) % 4).reinterpret_as_uint())
  } else if distance <= 32 {
    (8 + (distance - 17) / 8, 3, ((distance - 17) % 8).reinterpret_as_uint())
  } else if distance <= 64 {
    (10 + (distance - 33) / 16, 4, ((distance - 33) % 16).reinterpret_as_uint())
  } else if distance <= 128 {
    (12 + (distance - 65) / 32, 5, ((distance - 65) % 32).reinterpret_as_uint())
  } else if distance <= 256 {
    (
      14 + (distance - 129) / 64,
      6,
      ((distance - 129) % 64).reinterpret_as_uint(),
    )
  } else if distance <= 512 {
    (
      16 + (distance - 257) / 128,
      7,
      ((distance - 257) % 128).reinterpret_as_uint(),
    )
  } else if distance <= 1024 {
    (
      18 + (distance - 513) / 256,
      8,
      ((distance - 513) % 256).reinterpret_as_uint(),
    )
  } else if distance <= 2048 {
    (
      20 + (distance - 1025) / 512,
      9,
      ((distance - 1025) % 512).reinterpret_as_uint(),
    )
  } else if distance <= 4096 {
    (
      22 + (distance - 2049) / 1024,
      10,
      ((distance - 2049) % 1024).reinterpret_as_uint(),
    )
  } else if distance <= 8192 {
    (
      24 + (distance - 4097) / 2048,
      11,
      ((distance - 4097) % 2048).reinterpret_as_uint(),
    )
  } else if distance <= 16384 {
    (
      26 + (distance - 8193) / 4096,
      12,
      ((distance - 8193) % 4096).reinterpret_as_uint(),
    )
  } else if distance <= 32768 {
    (
      28 + (distance - 16385) / 8192,
      13,
      ((distance - 16385) % 8192).reinterpret_as_uint(),
    )
  } else {
    (29, 0, 0U)
  }

  tree.encode_symbol(writer, code)
  if extra_bits > 0 {
    writer.write_bits(extra_value, extra_bits)
  }
}

///|
pub fn deflate_compress_to_buffer(data : Bytes, level : Int) -> Buffer {
  let bytes = deflate_compress(data, level)
  let buf = Buffer::Buffer(size_hint=bytes.length())
  buf.write_bytes(bytes)
  buf
}
