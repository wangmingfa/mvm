///|
const RED = "\u{001B}[31m"

///|
const GREEN = "\u{001B}[32m"

///|
const YELLOW = "\u{001B}[33m"

///|
const BLUE = "\u{001B}[34m"

///|
const RESET = "\u{001B}[0m"

///|
/// 用指定颜色包裹文本，自动处理嵌套颜色（内层颜色结束后自动恢复外层颜色）
pub fn[T : Show] styled(color : String, msg : T) -> String {
  let content = msg.to_string()
  let patched = content.replace(old=RESET, new=color)
  "\{color}\{patched}\{RESET}"
}

///|
/// 红色文字
pub fn[T : Show] red(msg : T) -> String {
  styled(RED, msg)
}

///|
/// 绿色文字
pub fn[T : Show] green(msg : T) -> String {
  styled(GREEN, msg)
}

///|
/// 黄色文字
pub fn[T : Show] yellow(msg : T) -> String {
  styled(YELLOW, msg)
}

///|
/// 蓝色文字
pub fn[T : Show] blue(msg : T) -> String {
  styled(BLUE, msg)
}

///|
test "red" {
  println(red("这是红色文字"))
}

///|
test "green" {
  println(green("这是绿色文字"))
}

///|
test "yellow" {
  println(yellow("这是黄色文字"))
}

///|
test "blue" {
  println(blue("这是蓝色文字"))
}

///|
/// 嵌套颜色：红色文字中插入蓝色，后面的文字自动保持红色
test "nested color" {
  println(red("红色开头" + blue("蓝色中间") + "红色结尾"))
}

///|
/// 多层嵌套：红色包裹蓝色，蓝色包裹黄色
test "multi-level nested color" {
  let y = yellow("黄色")
  let b = blue("蓝色\{y}蓝色")
  println(red("红色\{b}红色"))
}
