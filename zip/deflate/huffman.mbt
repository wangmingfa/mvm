///|
pub struct HuffmanTree {
  counts : Array[UInt]
  codes : Array[UInt]
  code_lengths : Array[UInt]
  mut max_code_length : Int
  symbols_by_length : Array[Array[Int]]
}

///|
pub fn HuffmanTree::new(num_symbols : Int) -> HuffmanTree {
  {
    counts: Array::make(16, 0U),
    codes: Array::make(num_symbols, 0U),
    code_lengths: Array::make(num_symbols, 0U),
    max_code_length: 0,
    symbols_by_length: Array::make(16, []),
  }
}

///|
pub fn HuffmanTree::build_from_lengths(
  self : HuffmanTree,
  lengths : Array[UInt],
) -> Unit {
  let num_symbols = lengths.length()

  for i in 0..<16 {
    self.counts[i] = 0U
    self.symbols_by_length[i] = []
  }

  for i in 0..<num_symbols {
    let len = lengths[i]
    if len > 0 {
      self.counts[len.reinterpret_as_int()] = self.counts[len.reinterpret_as_int()] +
        1U
      self.symbols_by_length[len.reinterpret_as_int()].push(i)
    }
  }

  self.max_code_length = for i = 15; i >= 1; i = i - 1 {
    if self.counts[i] > 0 {
      break i
    }
  } nobreak {
    0
  }

  let mut code : UInt = 0U
  for bits in 1..<=self.max_code_length {
    let symbols = self.symbols_by_length[bits]
    for i in 0..<symbols.length() {
      let sym = symbols[i]
      self.codes[sym] = code
      self.code_lengths[sym] = bits.reinterpret_as_uint()
      code = code + 1U
    }
    code = code << 1
  }
}

///|
pub fn HuffmanTree::build_fixed_literal() -> HuffmanTree {
  let tree = HuffmanTree::new(288)
  let lengths = Array::make(288, 0U)

  for i in 0..<=143 {
    lengths[i] = 8U
  }
  for i in 144..<=255 {
    lengths[i] = 9U
  }
  for i in 256..<=279 {
    lengths[i] = 7U
  }
  for i in 280..<=287 {
    lengths[i] = 8U
  }

  tree.build_from_lengths(lengths)
  tree
}

///|
pub fn HuffmanTree::build_fixed_distance() -> HuffmanTree {
  let tree = HuffmanTree::new(32)
  let lengths = Array::make(32, 5U)
  tree.build_from_lengths(lengths)
  tree
}

///|
pub fn HuffmanTree::encode_symbol(
  self : HuffmanTree,
  writer : BitWriter,
  symbol : Int,
) -> Unit {
  let code = self.codes[symbol]
  let len = self.code_lengths[symbol].reinterpret_as_int()
  let mut reversed = 0U
  for i in 0..<len {
    reversed = (reversed << 1) | ((code >> i) & 1U)
  }
  writer.write_bits(reversed, len)
}

///|
pub fn HuffmanTree::decode_symbol(
  self : HuffmanTree,
  reader : BitReader,
) -> Int {
  let mut reversed_code = 0U

  for len in 1..<=self.max_code_length {
    let bit = reader.read_bits(1)
    reversed_code = reversed_code | (bit << (len - 1))

    // Reverse bits to get canonical code
    let mut code = 0U
    for j in 0..<len {
      code = (code << 1) | ((reversed_code >> j) & 1U)
    }

    // Compute first code for this length
    let mut first = 0U
    for bits in 1..<len {
      first = (first + self.counts[bits]) << 1
    }

    let count = self.counts[len]
    if code >= first && code < first + count {
      let offset = (code - first).reinterpret_as_int()
      return self.symbols_by_length[len][offset]
    }
  }

  -1
}
