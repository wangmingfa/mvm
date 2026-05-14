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
const CYAN = "\u{001B}[36m"

///|
/// MVM logo
const LOGO =
  #| ███╗   ███╗██╗   ██╗███╗   ███╗
  #| ████╗ ████║██║   ██║████╗ ████║
  #| ██╔████╔██║██║   ██║██╔████╔██║
  #| ██║╚██╔╝██║╚██╗ ██╔╝██║╚██╔╝██║
  #| ██║ ╚═╝ ██║ ╚████╔╝ ██║ ╚═╝ ██║
  #| ╚═╝     ╚═╝  ╚═══╝  ╚═╝     ╚═╝

///|
/// 打印 MVM logo
pub fn print_logo() -> Unit {
  println(styled(CYAN, LOGO))
}

///|
/// 用指定颜色包裹文本，自动处理嵌套颜色（内层颜色结束后自动恢复外层颜色）
pub fn[T : ToStr] styled(color : String, msg : T) -> String {
  let content = msg.to_str()
  let patched = content
    .split(RESET)
    .map(fn(v) { v.to_owned() })
    .collect()
    .join(color)
  "\{color}\{patched}\{RESET}"
}

///|
/// 红色文字
pub fn[T : ToStr] red(msg : T) -> String {
  styled(RED, msg)
}

///|
/// 绿色文字
pub fn[T : ToStr] green(msg : T) -> String {
  styled(GREEN, msg)
}

///|
/// 黄色文字
pub fn[T : ToStr] yellow(msg : T) -> String {
  styled(YELLOW, msg)
}

///|
/// 蓝色文字
pub fn[T : ToStr] blue(msg : T) -> String {
  styled(BLUE, msg)
}

///|
pub fn to_debug_string(msg : String) -> String {
  let mut result = msg
  for
    item in [
      (RED, "RED"),
      (GREEN, "GREEN"),
      (YELLOW, "YELLOW"),
      (BLUE, "BLUE"),
      (RESET, "RESET"),
    ] {
    let (color, str) = item
    result = result.replace_all(old=color, new="<\{str}>")
  }
  to_repr(result).to_string()
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
  let msg = red(
    "红色1" + blue("蓝色1") + "红色2" + blue("蓝色2") + "红色3",
  )
  println(msg)
  println(to_debug_string(msg))
}

///|
/// 多层嵌套：红色包裹蓝色，蓝色包裹黄色
test "multi-level nested color" {
  let y = yellow("黄色")
  let b = blue("蓝色\{y}蓝色")
  println(red("红色\{b}红色"))
}
