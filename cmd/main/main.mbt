///|
using @command {get_command, run}

///|
async fn main {
  guard @env.current_dir() is Some(_dir) else {
    raise fail("无法获取当前目录")
  }
  let args = @env.args()
  let arg_str = @utils.yellow(args)
  @log.debug("运行: \{arg_str}")
  // get_command 可能 raise，run 内部已捕获错误返回 CommandResult
  try {
    let command = get_command(args[1:])
    let result = run(command)
    if result.error is Some(err) {
      // 错误信息打印到 stderr
      @log.println_error(Failure::Failure(err))
    }
    if result.exit_code != 0 {
      @sys.exit(result.exit_code)
    }
  } catch {
    e => {
      @log.println_error(e)
      @sys.exit(1)
    }
  }
}
