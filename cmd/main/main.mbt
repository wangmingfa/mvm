///|
using @command {get_command, run}

///|
async fn main {
  guard @env.current_dir() is Some(_dir)
  let args = @env.args()[1:]
  @log.debug("参数: \{args}")
  try {
    let command = get_command(@env.args()[1:])
    run(command)
  } catch {
    e => @log.println_error(e)
  }
}
