///|
#borrow(suffix)
extern "C" fn c_progress_bar(
  completed : Int64,
  total : Int64,
  suffix : Bytes,
) -> Unit = "progress_bar"

///|
pub extern "C" fn clear_progress() -> Unit = "clear_progress"

///|
/// 一个辅助函数，将 MoonBit String 转换为 C 期望的 null-terminated byte array
fn string_to_c_bytes(s : String) -> Bytes {
  // let arr = s.to_bytes().to_array()
  let arr = @utf8.encode(s).to_array()
  // 确保以 \0 结尾
  if arr.last() != Some(0) {
    arr.push(0)
  }
  Bytes::from_array(arr)
}

///|
pub fn progress_bar(completed : Int64, total : Int64, suffix? : String) -> Unit {
  c_progress_bar(
    completed,
    total,
    string_to_c_bytes(if suffix is Some(s) { s } else { "" }),
  )
}

///|
async test "progress_bar" {
  let total = 50
  for i in 0..<=total {
    progress_bar(
      Int64::from_int(i + 1),
      total.to_int64(),
      suffix="downloading...",
    )
    @async.sleep(100)
  }
  clear_progress()
  println("下载完成")
}

///|
pub fn progress_bar_with_detailed_info(
  completed~ : Int64,
  total~ : Int64,
  start_time~ : Int64,
  period~ : Int64,
  completed_in_period~ : Int64,
) -> Unit {
  let (speed_str, current_speed) = @utils.get_speed_with_readable_unit(
    completed_in_period, period,
  )
  let time_info = @utils.get_duration_and_total_time(
    current_size=completed,
    file_size=total,
    start_time_ms=start_time,
    current_speed~,
  )
  progress_bar(completed, total, suffix="|  \{speed_str}  |  \{time_info}")
}

///|
async test "progress_bar_with_detailed_info" {
  let total : Int64 = 534_020_831
  let mut completed : Int64 = 0
  let step : Int64 = 3_612_341
  let start_time = @async.now()
  let period : Int64 = 100
  let sleep_time = period.to_int()
  while completed < total {
    completed += step
    progress_bar_with_detailed_info(
      completed~,
      total~,
      start_time~,
      period~,
      completed_in_period=step,
    )
    @async.sleep(sleep_time)
  }
  clear_progress()
  println("下载完成")
}

///|
pub struct ProgressBar {
  total : Int64
  mut competed : Int64
  start_time : Int64
  mut competed_time : Int64
  mut prev_time : Int64
  mut period : Int64
  mut completed_in_period : Int64
}

///|
pub fn ProgressBar::new(total : Int64) -> Self {
  let time = @async.now()
  {
    total,
    competed: 0,
    start_time: time,
    competed_time: 0,
    prev_time: time,
    period: 0,
    completed_in_period: 0,
  }
}

///|
fn ProgressBar::print(self : Self) -> Unit {
  progress_bar_with_detailed_info(
    completed=self.competed,
    total=self.total,
    start_time=self.start_time,
    period=self.period,
    completed_in_period=self.completed_in_period,
  )
}

///|
pub fn ProgressBar::set_completed(self : Self, completed : Int64) -> Unit {
  let completed = if completed > self.total { self.total } else { completed }
  let now = @async.now()
  let period = now - self.prev_time
  let completed_in_period = completed - self.competed
  self.competed = completed
  self.prev_time = now
  self.period = period
  self.completed_in_period = completed_in_period
  // 记录完成时间
  if completed == self.total {
    self.competed_time = now
  }
  self.print()
}

///|
pub fn ProgressBar::add_completed(self : Self, add : Int64) -> Unit {
  self.set_completed(self.competed + add)
}

///|
pub fn ProgressBar::set_complete(self : Self) -> Unit {
  self.set_completed(self.total)
}

///|
pub fn ProgressBar::is_completed(self : Self) -> Bool {
  self.competed >= self.total
}

///|
pub fn ProgressBar::clear() -> Unit {
  clear_progress()
}

///|
pub fn ProgressBar::duration(self : Self) -> Int64 {
  self.competed_time - self.start_time
}

///|
async test "ProgressBar" {
  let progress_bar = ProgressBar::new(81_456_789_33)
  while !progress_bar.is_completed() {
    progress_bar.add_completed(193_123_239)
    @async.sleep(300)
  }
  ProgressBar::clear()
  println("下载完成")
}
