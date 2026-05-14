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
  try {
    let command = get_command(args[1:])
    run(command)
  } catch {
    e => {
      @log.println_error(e)
      @sys.exit(1)
    }
  }
}
