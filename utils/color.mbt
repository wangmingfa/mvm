///|
/// 重置
const RESET = "\u{001B}[0m"

///|
pub(all) enum Color {
  Default
  Red
  Green
  Yellow
  Blue
  Cyan
}

///|
fn Color::to_cololr_str(self : Self) -> String {
  match self {
    Default => ""
    Red => "\u{001B}[31m"
    Green => "\u{001B}[32m"
    Yellow => "\u{001B}[33m"
    Blue => "\u{001B}[34m"
    Cyan => "\u{001B}[36m"
  }
}

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
/// 获取 MVM logo 纯文本（不带 ANSI 颜色代码）
pub fn get_logo_text() -> String {
  LOGO
}

///|
/// 打印 MVM logo（带青色样式）
pub fn print_logo() -> Unit {
  println(styled(Cyan, LOGO))
}

///|
/// 用指定颜色包裹文本，自动处理嵌套颜色（内层颜色结束后自动恢复外层颜色）
fn[T : ToStr] styled(color : Color, msg : T) -> String {
  let color = color.to_cololr_str()
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
pub fn[T : ToStr] default(msg : T) -> String {
  styled(Default, msg)
}

///|
pub fn[T : ToStr] red(msg : T) -> String {
  styled(Red, msg)
}

///|
/// 绿色文字
pub fn[T : ToStr] green(msg : T) -> String {
  styled(Green, msg)
}

///|
/// 黄色文字
pub fn[T : ToStr] yellow(msg : T) -> String {
  styled(Yellow, msg)
}

///|
/// 蓝色文字
pub fn[T : ToStr] blue(msg : T) -> String {
  styled(Blue, msg)
}

///|
/// 青色文字
pub fn[T : ToStr] cyan(msg : T) -> String {
  styled(Cyan, msg)
}

///|
/// 带颜色的文本片段列表
/// 适合在一次打印中，拼接多个带颜色文本
pub fn[T : ToStr] colored_spans(
  spans : Array[(Color, T)],
  joiner? : String = "",
) -> String {
  spans
  .map(span => {
    let (color, msg) = span
    styled(color, msg)
  })
  .join(joiner)
}

///|
pub fn to_debug_string(msg : String) -> String {
  let mut result = msg
  for
    item in [(Red, "RED"), (Green, "GREEN"), (Yellow, "YELLOW"), (Blue, "BLUE")] {
    let (color, str) = item
    let color = color.to_cololr_str()
    result = result.replace_all(old=color, new="<\{str}>")
  }
  result = result.replace_all(old=RESET, new="<RESET>")
  Repr(result).to_string()
}

///|
/// 去除字符串中的 ANSI 颜色控制码，返回纯文本
/// 移除 RESET 和所有 Color 枚举对应的 ANSI SGR 序列
pub fn strip_colors(text : String) -> String {
  let mut result = text.replace_all(old=RESET, new="")
  for item in [Red, Green, Yellow, Blue, Cyan] {
    result = result.replace_all(old=item.to_cololr_str(), new="")
  }
  result
}

///|
test "strip_colors 基础颜色剥离" {
  let colored = red("红色") + green("绿色") + blue("蓝色")
  debug_inspect(
    strip_colors(colored),
    content=(
      #|"红色绿色蓝色"
    ),
  )
  // 嵌套颜色
  let nested = red("红" + blue("蓝") + "红2")
  debug_inspect(
    strip_colors(nested),
    content=(
      #|"红蓝红2"
    ),
  )
  // 无颜色文本不受影响
  debug_inspect(
    strip_colors("纯文本"),
    content=(
      #|"纯文本"
    ),
  )
}

///|
test "color" {
  println(default("这是默认颜色文字"))
  println(red("这是红色文字"))
  println(green("这是绿色文字"))
  println(yellow("这是黄色文字"))
  println(blue("这是蓝色文字"))
  println(cyan("这是青色文字"))
  println(default("这是默认颜色文字"))
  let spans = [
    (Red, "红色1"),
    (Default, "默认颜色1"),
    (Red, "红色2"),
    (Green, "绿色1"),
    (Blue, "蓝色1"),
    (Green, "绿色2"),
    (Green, "绿色3"),
    (Blue, "蓝色2"),
    (Cyan, "青色1"),
    (Red, "红色"),
    (Default, "默认颜色2"),
  ]
  println(colored_spans(spans))
  println(colored_spans(spans, joiner=" | "))
  println(colored_spans(spans, joiner="\n"))
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
