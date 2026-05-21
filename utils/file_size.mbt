///|
/// 将传输速度转换为可读格式（如 "20.5 MB/s"），同时返回原始字节速度
/// show_unit: 是否显示单位（B/s/KB/s/MB/s/GB/s），默认为 true
pub fn get_readable_speed(
  size : Int64,
  duration : Int64,
  show_unit~ : Bool = true,
) -> (String, Int64) {
  if duration == 0 {
    // duration 为 0 时无法计算速度
    let str = if show_unit { "0 B/s" } else { "0" }
    return (str, 0)
  }
  let bytes_per_sec = size * 1000 / duration
  // 先计算数值部分和单位部分，最后根据 show_unit 决定是否拼接单位
  let (num_str, unit) = if bytes_per_sec < 1000L {
    ("\{bytes_per_sec}", "B/s")
  } else if bytes_per_sec < 1_000_000L {
    let kb_x10 = bytes_per_sec * 10L / 1000L
    ("\{kb_x10 / 10L}.\{kb_x10 % 10L}", "KB/s")
  } else if bytes_per_sec < 1_000_000_000L {
    let mb_x10 = bytes_per_sec * 10L / 1_000_000L
    ("\{mb_x10 / 10L}.\{mb_x10 % 10L}", "MB/s")
  } else {
    let gb_x10 = bytes_per_sec * 10L / 1_000_000_000L
    ("\{gb_x10 / 10L}.\{gb_x10 % 10L}", "GB/s")
  }
  let readable_str = if show_unit { "\{num_str} \{unit}" } else { num_str }
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
