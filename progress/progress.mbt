///|
/// 将字节大小转换为可读格式（如 "20.5 MB"）
/// show_unit: 是否显示单位（B/KB/MB/GB），默认为 true
fn format_size(bytes : Int64, show_unit? : Bool = true) -> String {
  if bytes < 1000 {
    if show_unit {
      "\{bytes} B"
    } else {
      "\{bytes}"
    }
  } else if bytes < 1_000_000 {
    let main = bytes / 1000
    let sub = bytes * 10 / 1000 % 10
    if show_unit {
      "\{main}.\{sub} KB"
    } else {
      "\{main}.\{sub}"
    }
  } else if bytes < 1_000_000_000 {
    let main = bytes / 1_000_000
    let sub = bytes * 10 / 1_000_000 % 10
    if show_unit {
      "\{main}.\{sub} MB"
    } else {
      "\{main}.\{sub}"
    }
  } else {
    let main = bytes / 1_000_000_000
    let sub = bytes * 10 / 1_000_000_000 % 10
    if show_unit {
      "\{main}.\{sub} GB"
    } else {
      "\{main}.\{sub}"
    }
  }
}

///|
/// 构建进度条字符串（如 "[======>               ]"）
fn build_bar(filled : Int, bar_width : Int) -> String {
  let mut bar = ""
  for _ in 0..<filled {
    bar = bar + "="
  }
  if filled < bar_width {
    bar = bar + ">"
    let remaining = bar_width - filled - 1
    for _ in 0..<remaining {
      bar = bar + " "
    }
  }
  bar
}

///|
pub fn progress_bar(
  prefix? : String,
  completed : Int64,
  total : Int64,
  suffix? : String,
  show_unit? : Bool = true,
) -> Unit {
  // 限制 completed 不超过 total
  let completed = if completed > total { total } else { completed }
  if total <= 0 {
    return
  }
  let bar_width = 50
  let percent = (completed * 100 / total).to_int()
  let filled = (completed * bar_width.to_int64() / total).to_int()
  let bar = build_bar(filled, bar_width)
  let completed_str = format_size(completed, show_unit~)
  let total_str = format_size(total, show_unit~)
  let prefix_str = if prefix is Some(s) && !s.is_blank() { "\{s} " } else { "" }
  let suffix_str = if suffix is Some(s) { s } else { "" }
  // \r 回到行首覆盖上一行内容
  @stdio.print(
    "\r\{prefix_str}[\{bar}] \{completed_str} / \{total_str}  (\{percent}%)  \{suffix_str}",
  )
  @stdio.flush_stdout()
}

///|
async test "progress_bar" {
  // 仅验证进度条渲染，减少迭代次数和 sleep 时间
  let total = 5
  for i in 0..<=total {
    progress_bar(
      Int64::from_int(i + 1),
      total.to_int64(),
      suffix="downloading...",
    )
    @async.sleep(50)
  }
  @stdio.clear_lines(1)
  println("下载完成")
}

///|
fn progress_bar_with_detailed_info(
  prefix? : String,
  completed~ : Int64,
  total~ : Int64,
  start_time~ : Int64,
  period~ : Int64,
  completed_in_period~ : Int64,
  show_speed? : Bool = true,
  show_time_info? : Bool = true,
  show_unit? : Bool = true,
) -> Unit {
  let (speed_str, current_speed) = @utils.get_readable_speed(
    completed_in_period,
    period,
    show_unit~,
  )
  let time_info = @utils.get_duration_and_total_time(
    current_size=completed,
    file_size=total,
    start_time_ms=start_time,
    current_speed~,
  )
  let suffixes = []
  if show_speed {
    suffixes.push("|  \{speed_str}")
  }
  if show_time_info {
    suffixes.push("|  \{time_info}")
  }
  progress_bar(prefix?, completed, total, suffix=suffixes.join(" "), show_unit~)
}

///|
async test "progress_bar_with_detailed_info" {
  // 仅验证进度条+速度/时间信息渲染，大幅减少模拟数据量和等待时间
  let total : Int64 = 100_000_000
  let mut completed : Int64 = 0
  let step : Int64 = 20_000_000
  let start_time = @async.now()
  let period : Int64 = 100
  let sleep_time = period.to_int()
  while completed < total {
    completed += step
    progress_bar_with_detailed_info(
      prefix="下载进度",
      completed~,
      total~,
      start_time~,
      period~,
      completed_in_period=step,
      show_speed=false,
      show_time_info=false,
    )
    @async.sleep(sleep_time)
  }
  @stdio.clear_lines(1)
  println("下载完成")
}

///|
pub(all) enum ProgressBarMode {
  Full
  Simple
}

///|
pub struct ProgressBar {
  prefix : String
  mode : ProgressBarMode
  show_speed : Bool
  show_time_info : Bool
  show_unit : Bool
  total : Int64
  mut competed : Int64
  start_time : Int64
  mut competed_time : Int64
  mut prev_time : Int64
  mut period : Int64
  mut completed_in_period : Int64
}

///|
pub fn ProgressBar::ProgressBar(
  total : Int64,
  prefix? : String = "",
  mode? : ProgressBarMode = Full,
  show_speed? : Bool = true,
  show_time_info? : Bool = true,
  show_unit? : Bool = true,
) -> Self {
  let time = @async.now()
  {
    prefix,
    mode,
    show_speed,
    show_time_info,
    show_unit,
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
fn ProgressBar::percent(self : Self) -> Int {
  (self.competed * 100 / self.total).to_int()
}

///|
fn ProgressBar::print(self : Self) -> Unit {
  match self.mode {
    Full =>
      progress_bar_with_detailed_info(
        prefix=self.prefix,
        completed=self.competed,
        total=self.total,
        start_time=self.start_time,
        period=self.period,
        completed_in_period=self.completed_in_period,
        show_speed=self.show_speed,
        show_time_info=self.show_time_info,
        show_unit=self.show_unit,
      )
    Simple => simple_progress_bar(prefix=self.prefix, self.percent())
  }
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
pub fn ProgressBar::set_completed_int(self : Self, completed : Int) -> Unit {
  self.set_completed(completed.to_int64())
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
pub fn ProgressBar::clear(_ : Self) -> Unit {
  // 覆盖当前行的内容
  println("")
  @stdio.clear_lines(1)
}

///|
pub fn ProgressBar::duration(self : Self) -> Int64 {
  self.competed_time - self.start_time
}

///|
async test "ProgressBar" {
  // 仅验证 ProgressBar 结构体逻辑，大幅减少模拟数据量和等待时间
  let progress_bar = ProgressBar(100_000_000)
  while !progress_bar.is_completed() {
    progress_bar.add_completed(20_000_000)
    @async.sleep(50)
  }
  progress_bar.clear()
  println("下载完成")
}

///|
/// 简单进度条
///   prefix 前缀信息
///   percent 进度百分比，0-100
fn simple_progress_bar(prefix? : String = "", percent : Int) -> Unit {
  // 将百分比限制在 0-100 范围内
  let percent = if percent < 0 {
    0
  } else if percent > 100 {
    100
  } else {
    percent
  }
  // 进度条总宽度
  let bar_width = 30
  let filled = percent * bar_width / 100
  let bar = build_bar(filled, bar_width)
  // \r 回到行首覆盖上一行内容
  @stdio.print("\r\{prefix}[\{bar}] \{percent}%")
  @stdio.flush_stdout()
}

///|
async test "simple_progress_bar" {
  let progress_bar = ProgressBar(100, mode=Simple)
  for i in 1..<=10 {
    progress_bar.set_completed_int(i * 10)
    @async.sleep(100)
  }
  println("")
  @stdio.clear_lines(1)
}
