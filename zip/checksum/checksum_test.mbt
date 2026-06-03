///|
test "adler32 - empty input" {
  let result = adler32(b"")
  inspect(result, content="1")
}

///|
test "adler32 - simple string" {
  let result = adler32(b"hello")
  inspect(
    result,
    content=(
      #|103547413
    ),
  )
}

///|
test "adler32 - wikipedia example" {
  let result = adler32(b"Wikipedia")
  inspect(result, content="300286872")
}

///|
test "adler32 - incremental" {
  let full = adler32(b"hello world")
  inspect(full, content="436929629")
}

///|
test "crc32 - empty input" {
  let result = crc32(b"")
  inspect(result, content="0")
}

///|
test "crc32 - simple string" {
  let result = crc32(b"hello")
  inspect(result, content="907060870")
}

///|
test "crc32 - wikipedia example" {
  let result = crc32(b"Wikipedia")
  inspect(
    result,
    content=(
      #|2913648686
    ),
  )
}

///|
test "crc32 - incremental" {
  let full = crc32(b"hello world")
  inspect(full, content="222957957")
}

///|
test "crc32 - binary data" {
  let data = b"\x00\x01\x02\x03\x04\x05"
  let result = crc32(data)
  inspect(
    result,
    content=(
      #|820760394
    ),
  )
}
