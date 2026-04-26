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
pub fn[T : Show] red(msg : T) -> String {
  "\{RED}\{msg}\{RESET}"
}

///|
pub fn[T : Show] green(msg : T) -> String {
  "\{GREEN}\{msg}\{RESET}"
}

///|
pub fn[T : Show] yellow(msg : T) -> String {
  "\{YELLOW}\{msg}\{RESET}"
}

///|
pub fn[T : Show] blue(msg : T) -> String {
  "\{BLUE}\{msg}\{RESET}"
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
