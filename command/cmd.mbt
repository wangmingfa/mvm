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
      let code = @process.run("command", ["-v", cmd]) catch {
        _ => return false
      }
      code == 0
    }
    _ => false
  }
}

///|
/// 自动选择最佳下载器
pub async fn get_best_downloader() -> String? {
  let os = @os.get_os_name()
  match os {
    Windows => {
      // Windows: 优先用 curl.exe (Win10+自带)，其次用 PowerShell
      let cmds = ["curl.exe", "powershell"]
      for cmd in cmds {
        if command_exists(cmd) {
          return Some(cmd)
        }
      }
      None
    }
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
