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
    Linux => {
      // Linux: 优先用 wget，其次用 curl
      let cmds = ["wget", "curl"]
      for cmd in cmds {
        if command_exists(cmd) {
          return Some(cmd)
        }
      }
      None
    }
    MacOS => {
      // macOS: curl 是系统自带工具，优先使用；wget 通常需额外安装
      let cmds = ["curl", "wget"]
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
fn get_cmd_and_args(
  cmd : String,
  args : ArrayView[String],
) -> (String, ArrayView[String]) {
  // 在windows下，需要使用powershell -Command
  let os = @os.get_os_name()
  match os {
    Windows => ("powershell", ["-Command", cmd + " " + join_args(args)])
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
  let arg_str = join_args(args)
  @log.debug("运行: \{cmd} \{arg_str}")
  @process.run(cmd, args, extra_env~)
}

///|
/// 为文件添加可执行权限（仅MacOS/Linux生效，Windows无需处理）
pub async fn chmod_x(file_paths : Array[String]) -> Unit {
  let os = @os.get_os_name()
  match os {
    MacOS | Linux => {
      let _ = @process.run("chmod", ["+x", ..file_paths])
    }
    _ => ()
  }
}

///|
fn join_args(args : ArrayView[String]) -> String {
  // 如果有空格，则使用引号包裹
  args.map(v => if v.contains(" ") { "\"\{v}\"" } else { v }).join(" ")
}

///|
#borrow(str)
extern "C" fn c_print(str : Bytes) -> Unit = "print"

///|
pub fn print(str : String) -> Unit {
  c_print(@ffi.string_to_c_bytes(str))
}

///|
test "print" {
  print("a")
  print("b")
  print("c")
  print("d")
  print("e")
  println("")
}

///|
pub async fn run_with_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &@process.ProcessInput,
  cwd? : StringView,
) -> (Int, &@io.Data) {
  let (r, w) = @process.read_from_process()
  let (exit_code, output) = @async.with_task_group(group => {
    defer r.close()
    let output = group.spawn(() => {
      let buffer = @buffer.new()
      while r.read_some() is Some(b) {
        print(@utf8.decode_lossy(b))
        buffer.write_bytes(b)
      }
      buffer.contents()
    })
    let exit_code = group.spawn(() => {
      @process.run(
        cmd,
        args,
        extra_env~,
        inherit_env~,
        stdin?,
        stdout=w,
        stderr=w,
        cwd?,
      )
    })
    (exit_code.wait(), output.wait())
  })
  (exit_code, output)
}
