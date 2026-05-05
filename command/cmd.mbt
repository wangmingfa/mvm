// 检查命令是否存在

///|
pub async fn command_exists(cmd : String) -> Bool {
  let os = @os.get_os_name()
  match os {
    Linux | MacOS => {
      let (code, output) = @process.collect_stdout("which", [cmd]) catch {
        _ => return false
      }
      code == 0 && !output.text().is_blank()
    }
    Windows => {
      // cmd
      let code = @process.run("where", [cmd]) catch { _ => 1 }
      if code == 0 {
        return true
      }
      // PowerShell
      let (cmd, args) = get_cmd_and_args("Get-Command", [cmd])
      let code = @process.run(cmd, args) catch {
        _ =>
          // println(e)
          return false
      }
      // println("code: \{code}")
      code == 0
    }
    _ => false
  }
}

///|
async test "command_exists" {
  debug_inspect(
    command_exists("node"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    command_exists("code"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    command_exists("wget"),
    content=(
      #|true
    ),
  )
  debug_inspect(
    command_exists("nonexistentcmd"),
    content=(
      #|false
    ),
  )
}

///|
/// 自动选择最佳下载器
pub async fn get_best_downloader() -> String? {
  let os = @os.get_os_name()
  match os {
    Windows =>
      // Windows: 优先用 curl.exe (Win10+自带)，其次用 PowerShell
      // let cmds = ["wget", "curl.exe", "powershell"]
      // for cmd in cmds {
      //   if command_exists(cmd) {
      //     return Some(cmd)
      //   }
      // }
      // None
      Some("powershell")
    Linux | MacOS => {
      // Linux/macOS: 优先用 curl，其次用 wget
      let cmds = ["wget", "curl"]
      for cmd in cmds {
        if command_exists(cmd) {
          return Some(cmd)
        }
      }
      None
    }
    _ => None
  }
}

///|
async test "get_best_downloader" {
  debug_inspect(
    get_best_downloader(),
    content=(
      #|Some("curl")
    ),
  )
}

///|
pub fn get_cmd_and_args(
  cmd : String,
  args : ArrayView[String],
) -> (String, ArrayView[String]) {
  // 在windows下，需要使用powershell -Command
  let os = @os.get_os_name()
  match os {
    Windows => ("powershell", ["-Command", cmd + " " + args.join(" ")])
    _ => (cmd, args)
  }
}

///|
async test "run node -v" {
  let (cmd, args) = get_cmd_and_args("node", ["-v"])
  let arg_str = args.join(" ")
  println("命令：\{cmd} \{arg_str}")
  let _ = @process.run(cmd, args)
}

///|
pub async fn run(
  cmd : String,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
) -> Int {
  let (cmd, args) = get_cmd_and_args(cmd, args)
  @process.run(cmd, args, extra_env~)
}
