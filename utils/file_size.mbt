///|
pub fn get_speed_with_readable_unit(
  size : Int64,
  duration : Int64,
) -> (String, Int64) {
  if duration == 0 {
    return ("0 B/s", 0)
  }
  let bytes_per_sec = size * 1000 / duration
  let readable_str = if bytes_per_sec < 1000L {
    "\{bytes_per_sec} B/s"
  } else if bytes_per_sec < 1_000_000L {
    let kb_x10 = bytes_per_sec * 10L / 1000L
    "\{kb_x10 / 10L}.\{kb_x10 % 10L} KB/s"
  } else if bytes_per_sec < 1_000_000_000L {
    let mb_x10 = bytes_per_sec * 10L / 1_000_000L
    "\{mb_x10 / 10L}.\{mb_x10 % 10L} MB/s"
  } else {
    let gb_x10 = bytes_per_sec * 10L / 1_000_000_000L
    "\{gb_x10 / 10L}.\{gb_x10 % 10L} GB/s"
  }
  (readable_str, bytes_per_sec)
}

///|
pub fn get_readable_file_size(size : Int64) -> String {
  if size < 1000L {
    "\{size} B"
  } else if size < 1_000_000L {
    let kb_x10 = size * 10L / 1000L
    "\{kb_x10 / 10L}.\{kb_x10 % 10L} KB"
  } else if size < 1_000_000_000L {
    let mb_x10 = size * 10L / 1_000_000L
    "\{mb_x10 / 10L}.\{mb_x10 % 10L} MB"
  } else {
    let gb_x10 = size * 10L / 1_000_000_000L
    "\{gb_x10 / 10L}.\{gb_x10 % 10L} GB"
  }
}

///|
test "get_readable_file_size" {
  inspect(get_readable_file_size(500), content="500 B")
  inspect(get_readable_file_size(1500), content="1.5 KB")
  inspect(get_readable_file_size(1_500_000), content="1.5 MB")
  inspect(get_readable_file_size(1_500_000_000), content="1.5 GB")
}
