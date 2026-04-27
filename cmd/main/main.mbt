///|
using @command {get_command, run}

///|
async fn main {
  guard @env.current_dir() is Some(_dir)
  // println("当前目录：\{dir}")
  try {
    let command = get_command(@env.args()[1:]) catch {
      e => {
        println(e)
        return
      }
    }
    run(command)
  } catch {
    Failure::Failure(s) => println(s)
    e => println(e)
  }
}
