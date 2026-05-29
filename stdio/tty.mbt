///|
extern "C" fn c_is_stdin_tty() -> Int = "is_stdin_tty"

///|
extern "C" fn c_is_stdout_tty() -> Int = "is_stdout_tty"

///|
extern "C" fn c_is_stderr_tty() -> Int = "is_stderr_tty"

///|
/// 检查标准输入是否为 TTY 终端
pub fn is_stdin_tty() -> Bool {
  c_is_stdin_tty() != 0
}

///|
/// 检查标准输出是否为 TTY 终端
pub fn is_stdout_tty() -> Bool {
  c_is_stdout_tty() != 0
}

///|
/// 检查标准错误是否为 TTY 终端
pub fn is_stderr_tty() -> Bool {
  c_is_stderr_tty() != 0
}

///|
test "tty" {
  let stdin_tty = is_stdin_tty()
  let stdout_tty = is_stdout_tty()
  let stderr_tty = is_stderr_tty()
  inspect(
    stdin_tty,
    content=(
      #|false
    ),
  )
  inspect(
    stdout_tty,
    content=(
      #|false
    ),
  )
  inspect(
    stderr_tty,
    content=(
      #|false
    ),
  )
}
