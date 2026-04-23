///|
pub fn get_readable_time(ms : Int64) -> String {
  if ms < 1000L {
    "\{ms}ms"
  } else if ms < 60_000L {
    let sec_x10 = ms * 10L / 1000L
    "\{sec_x10 / 10L}.\{sec_x10 % 10L}s"
  } else if ms < 3_600_000L {
    let total_sec = ms / 1000L
    let min = total_sec / 60L
    let sec = total_sec % 60L
    "\{min}m \{sec}s"
  } else {
    let total_sec = ms / 1000L
    let hour = total_sec / 3600L
    let min = total_sec % 3600L / 60L
    let sec = total_sec % 60L
    "\{hour}h \{min}m \{sec}s"
  }
}

///|
fn pad_two(n : Int64) -> String {
  if n < 10L {
    "0\{n}"
  } else {
    "\{n}"
  }
}

///|
fn format_duration(ms : Int64, use_hour_format : Bool) -> String {
  let total_sec = ms / 1000L
  let hours = total_sec / 3600L
  let mins = total_sec % 3600L / 60L
  let secs = total_sec % 60L
  if use_hour_format {
    "\{pad_two(hours)}:\{pad_two(mins)}:\{pad_two(secs)}"
  } else {
    "\{pad_two(mins)}:\{pad_two(secs)}"
  }
}

///|
/// 获取当前耗时，以及预估总时间。
/// 返回格式：
///   分钟：00:12 / 01:30
///   小时：01:10:12 / 02:01:30
pub fn get_duration_and_total_time(
  current_size~ : Int64,
  file_size~ : Int64,
  start_time_ms~ : Int64,
  current_speed~ : Int64,
) -> String {
  let current_time = @async.now()
  let duration_ms = current_time - start_time_ms
  if file_size <= 0L {
    let duration_str = format_duration(duration_ms, false)
    return "\{duration_str} / --:--"
  }
  let remaining_size = file_size - current_size
  let total_ms = if current_speed > 0L {
    // 基于实时速度预估剩余时间（current_speed 单位: bytes/s）
    let remaining_ms = remaining_size * 1000L / current_speed
    duration_ms + remaining_ms
  } else if current_size > 0L && duration_ms > 0L {
    // 基于平均速度预估
    duration_ms / current_size * file_size +
    duration_ms % current_size * file_size / current_size
  } else {
    // 无法计算
    let duration_str = format_duration(duration_ms, false)
    return "\{duration_str} / --:--"
  }
  let use_hour_format = total_ms >= 3_600_000L
  let duration_str = format_duration(duration_ms, use_hour_format)
  let total_str = format_duration(total_ms, use_hour_format)
  "\{duration_str} / \{total_str}"
}

///|
test "get_duration_and_total_time" {
  // current_speed=10000 bytes/s, file_size=1000000 bytes
  // 预估总时间 = 0 + 1000000*1000/10000 = 100000ms = 1m40s
  inspect(
    get_duration_and_total_time(
      current_size=100000,
      file_size=1000 * 1000,
      start_time_ms=@async.now(),
      current_speed=10000,
    ),
    content=(
      #|00:00 / 01:30
    ),
  )
}

///|
test "get_duration_and_total_time no info" {
  inspect(
    get_duration_and_total_time(
      current_size=0,
      file_size=1000 * 1000,
      start_time_ms=@async.now(),
      current_speed=0,
    ),
    content=(
      #|00:00 / --:--
    ),
  )
}
