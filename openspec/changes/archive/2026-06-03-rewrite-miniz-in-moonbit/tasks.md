# Tasks: Rewrite miniz.c in Pure MoonBit

## Phase 1: Foundation - Checksum and Bit I/O

- [x] 1.1 Create `zip/checksum/` package structure
  - [x] 1.1.1 Create `zip/checksum/moon.pkg`
  - [x] 1.1.2 Create `zip/checksum/adler32.mbt` with `adler32()` function
  - [x] 1.1.3 Create `zip/checksum/crc32.mbt` with `crc32()` function and lookup table
  - [x] 1.1.4 Add unit tests for Adler-32 and CRC-32

- [x] 1.2 Create `zip/deflate/` package structure
  - [x] 1.2.1 Create `zip/deflate/moon.pkg`
  - [x] 1.2.2 Create `zip/deflate/bitbuf.mbt` with `BitReader` and `BitWriter` types
  - [x] 1.2.3 Implement `read_bits()`, `peek_bits()`, `write_bits()`, `flush()` methods
  - [x] 1.2.4 Add unit tests for bit buffer I/O

## Phase 2: Huffman Coding

- [x] 2.1 Create `zip/deflate/huffman.mbt`
  - [x] 2.1.1 Define `HuffmanTree` type for decoding
  - [x] 2.1.2 Implement `build_huffman_tree(code_lengths)` function
  - [x] 2.1.3 Implement `decode_symbol(reader, tree)` function
  - [x] 2.1.4 Add fixed Huffman tables (RFC 1951 §3.2.6) as constants
  - [x] 2.1.5 Implement Huffman encoding: frequency counting → code length calculation → canonical Huffman code generation
  - [x] 2.1.6 Add unit tests for Huffman coding

## Phase 3: DEFLATE Compression

- [x] 3.1 Create `zip/deflate/compress.mbt`
  - [x] 3.1.1 Implement LZ77 matching with hash chain for longest match finding
  - [x] 3.1.2 Implement stored block (no compression, level 0)
  - [x] 3.1.3 Implement static Huffman block (fixed tables)
  - [x] 3.1.4 Implement dynamic Huffman block (custom tables)
  - [x] 3.1.5 Implement compression levels 1-9 (1=fast, 6=default, 9=best)
  - [x] 3.1.6 Implement `deflate_compress(data, level)` public API
  - [x] 3.1.7 Add unit tests: compress known data, verify it's valid DEFLATE

## Phase 4: DEFLATE Decompression

- [x] 4.1 Create `zip/deflate/decompress.mbt`
  - [x] 4.1.1 Implement state machine for block decoding
  - [x] 4.1.2 Implement stored block decoding (direct copy)
  - [x] 4.1.3 Implement static Huffman block decoding
  - [x] 4.1.4 Implement dynamic Huffman block decoding (read custom tables)
  - [x] 4.1.5 Implement LZ77 back-reference resolution with 32KB sliding window
  - [x] 4.1.6 Implement `inflate_decompress(data, expected_size)` public API
  - [x] 4.1.7 Add unit tests: decompress data compressed in Phase 3

## Phase 5: Zlib Format

- [x] 5.1 Create `zip/zlib/` package structure
  - [x] 5.1.1 Create `zip/zlib/moon.pkg`
  - [x] 5.1.2 Create `zip/zlib/zlib.mbt`
  - [x] 5.1.3 Implement `zlib_compress()`: write CMF+FLG header + DEFLATE data + Adler-32
  - [x] 5.1.4 Implement `zlib_decompress()`: verify header + DEFLATE decompress + verify Adler-32
  - [x] 5.1.5 Add unit tests: roundtrip compression/decompression

## Phase 6: ZIP Reading

- [x] 6.1 Create `zip/reader/` package structure
  - [x] 6.1.1 Create `zip/reader/moon.pkg`
  - [x] 6.1.2 Create `zip/reader/structs.mbt` with `ZipFileEntry`, `ZipArchive` types and constants
  - [x] 6.1.3 Create `zip/reader/endian.mbt` with `read_le16()`, `read_le32()`, `read_le64()`, `write_le16()`, `write_le32()`, `write_le64()`
  - [x] 6.1.4 Create `zip/reader/reader.mbt`
  - [x] 6.1.5 Implement EOCD (End of Central Directory) record parsing
  - [x] 6.1.6 Implement Central Directory parsing
  - [x] 6.1.7 Implement Local File Header parsing
  - [x] 6.1.8 Implement file extraction with DEFLATE decompression
  - [x] 6.1.9 Add ZIP64 support (when sizes are 0xFFFFFFFF)
  - [x] 6.1.10 Implement `open_zip()`, `extract_all()`, `extract_file()` public APIs
  - [x] 6.1.11 Add unit tests: read a known ZIP file, verify contents

## Phase 7: ZIP Writing

- [x] 7.1 Create `zip/writer/` package structure
  - [x] 7.1.1 Create `zip/writer/moon.pkg`
  - [x] 7.1.2 Create `zip/writer/writer.mbt`
  - [x] 7.1.3 Implement `ZipWriter` type with file handle and central directory buffer
  - [x] 7.1.4 Implement `add_file()`: write Local File Header + compressed data
  - [x] 7.1.5 Implement `add_directory()`: write directory entry
  - [x] 7.1.6 Implement `add_directory_recursive()`: walk directory tree and add all files
  - [x] 7.1.7 Implement `finalize()`: write Central Directory + EOCD record
  - [x] 7.1.8 Implement `create_zip()` public API
  - [x] 7.1.9 Add unit tests: create ZIP, read it back, verify contents

## Phase 8: Integration and Cleanup

- [x] 8.1 Update `zip/zip.mbt`
  - [x] 8.1.1 Rewrite `unzip()` to use `zip/reader` instead of C FFI
  - [x] 8.1.2 Rewrite `zip()` to use `zip/writer` instead of system commands
  - [x] 8.1.3 Keep the same public API signatures
  - [x] 8.1.4 Update existing test in `zip.mbt` to work with new implementation

- [x] 8.2 Update `zip/moon.pkg`
  - [x] 8.2.1 Remove `native-stub` option
  - [x] 8.2.2 Add dependencies on new subpackages
  - [x] 8.2.3 Remove `username/mvm/command` dependency if no longer needed

- [x] 8.3 Delete C files
  - [x] 8.3.1 Delete `zip/miniz.c`
  - [x] 8.3.2 Delete `zip/miniz.h`
  - [x] 8.3.3 Delete `zip/zip.c`

- [x] 8.4 Run full test suite
  - [x] 8.4.1 Run `moon test` to verify all tests pass
  - [x] 8.4.2 Run `moon info && moon fmt` to update interfaces and format code
  - [x] 8.4.3 Verify no regressions in packages that depend on `zip`

## Phase 9: Cross-Validation Tests (MoonBit vs System Commands)

- [x] 9.1 Create test helper `zip/test_helper_wbtest.mbt`
  - [x] 9.1.1 Implement `system_zip()` / `system_unzip()` wrappers
  - [x] 9.1.2 Implement `files_equal()` / `dir_tree_equal()` / `read_file_bytes()` helpers
  - [x] 9.1.3 Generate test fixtures: empty file, short text, >1MB binary, nested dirs

- [x] 9.2 Checksum cross-validation tests
  - [x] 9.2.1 Adler-32: use `gzip` to compress test data, then MoonBit decompresses and verifies Adler-32 matches
  - [x] 9.2.2 CRC-32: use `zip` to package test files, then MoonBit reads Central Directory CRC-32 field and compares with `crc32()` result
  - [x] 9.2.3 Edge cases: empty input, single byte, >5552 bytes (Adler block boundary), binary data

- [x] 9.3 DEFLATE cross-validation tests
  - [x] 9.3.1 Roundtrip: `inflate(deflate(data)) == data` for varied inputs
  - [x] 9.3.2 MoonBit compress → Python `zlib.decompress()` succeeds and matches original
  - [x] 9.3.3 Python `zlib.compress()` → MoonBit decompress succeeds and matches original
  - [x] 9.3.4 Test across compression levels 0, 1, 6, 9
  - [x] 9.3.5 Test data patterns: empty, repetitive (high ratio), random binary (low ratio), >1MB

- [x] 9.4 ZIP cross-validation tests
  - [x] 9.4.1 MoonBit `zip()` → system `unzip`: verify extracted files match source directory
  - [x] 9.4.2 System `zip` → MoonBit `unzip()`: verify extracted files match source directory
  - [x] 9.4.3 Multi-file with subdirectories: both directions, verify directory tree and file contents
  - [x] 9.4.4 Empty files: MoonBit handles zero-length entries correctly in both directions
  - [x] 9.4.5 Large files (>1MB): verify CRC-32 and content match in both directions
  - [x] 9.4.6 File permissions and timestamps: best-effort preservation check

- [x] 9.5 Regression tests using existing test in `zip.mbt`
  - [x] 9.5.1 Ensure the original `async test "unzip"` still passes with new implementation
  - [x] 9.5.2 Add new test cases covering: nested directories, mixed file sizes, special characters in filenames

- [x] 9.6 Snapshot tests for stable outputs
  - [x] 9.6.1 Snapshot Adler-32 / CRC-32 values for canonical test vectors
  - [x] 9.6.2 Snapshot decompressed output of known ZIP fixtures (to detect behavior drift)

## Acceptance Criteria

- All miniz.c functionality (DEFLATE, zlib, ZIP read/write) implemented in pure MoonBit
- No C code or FFI calls in the zip package
- No system command calls (no `zip`, `Compress-Archive`, etc.) in production code
- Existing `unzip()` and `zip()` APIs work identically from caller's perspective
- **Cross-validation: MoonBit output can be decompressed by system tools; system tool output can be decompressed by MoonBit**
- **All cross-validation tests pass for checksum, DEFLATE, and ZIP layers**
- All tests pass
- Code formatted with `moon fmt`
