///|
using @time {type PlainDateTime, type ZoneOffset}

///|
pub fn get_date(milliseconds? : Int64 = @async.now()) -> PlainDateTime raise {
  PlainDateTime::from_unix_second(
    milliseconds / 1000,
    0,
    ZoneOffset::of(hours=8),
  )
}

///|
pub fn get_date_str(date? : PlainDateTime) -> String raise {
  // 这里的默认值如果放在参数中设置，会报错
  let date = if date is Some(date) { date } else { get_date() }
  "\{date.to_plain_date().to_string()} \{date.to_plain_time().to_string()}"
}

///|
test "get_date_str" {
  println(get_date_str())
}
