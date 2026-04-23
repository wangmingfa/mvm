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
pub fn red(msg : String) -> String {
  "\{RED}\{msg}\{RESET}"
}

///|
pub fn green(msg : String) -> String {
  "\{GREEN}\{msg}\{RESET}"
}

///|
pub fn yellow(msg : String) -> String {
  "\{YELLOW}\{msg}\{RESET}"
}

///|
pub fn blue(msg : String) -> String {
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
