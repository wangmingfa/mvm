///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let command = @lib.get_command(@env.args()[1:]) catch {
    e => {
      println(e)
      return
    }
  }
  println("命令：\{command}")
}
