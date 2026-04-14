///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
async fn main {
  guard @env.current_dir() is Some(dir)
  println("当前目录：\{dir}")
  let command = @lib.get_command(@env.args()[1:]) catch {
    e => {
      println(e)
      return
    }
  }
  run(command)
}
