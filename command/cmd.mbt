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
priv struct CommandResult {
  mut exit_code : Int
  mut output : String
}

///|
type RunCommandCallback[T] = FuncRef[(Int, String, T) -> Unit]

///|
#borrow(cmd, cwd, user_data, envs)
extern "C" fn c_run_command(
  cmd : Bytes,
  cwd : Bytes,
  envs : Bytes,
  callback : RunCommandCallback[CommandResult],
  user_data : CommandResult,
) -> Unit = "run_command"

///|
pub fn run_command(
  cmd : String,
  args : ArrayView[String],
  cwd? : String = "",
  extra_env? : Map[String, String] = {},
) -> (Int, String) {
  let cmd = join_args([cmd, ..args])
  @log.debug("运行命令 \{cmd}")
  @log.debug("工作目录 \{cwd}")
  @log.debug("环境变量 \{to_repr(extra_env)}")

  let cmd = @ffi.string_to_c_bytes(cmd)
  let cwd = @ffi.string_to_c_bytes(cwd)
  let envs = @ffi.string_to_c_bytes(
    extra_env.to_array().map(v => "\{v.0}=\{v.1}").join("&"),
  )
  let user_data = CommandResult::{ exit_code: 0, output: "" }
  c_run_command(
    cmd,
    cwd,
    envs,
    fn(exit_code, output, user_data) {
      user_data.exit_code = exit_code
      user_data.output = output
    },
    user_data,
  )
  (user_data.exit_code, user_data.output)
}

///|
async test "run_command" {
  guard @env.current_dir() is Some(dir)
  let temp_dir = "\{dir}/.temp"
  guard @fs.exists(temp_dir) else { @fs.mkdir(temp_dir, recursive=true) }
  let temp_file = "\{temp_dir}/run_command.sh"
  let envs = { "TEST01": "\{@env.now()}", "TEST02": "\{@env.now()}" }
  let env_keys = envs.keys().map(v => "\"$\{v}\"").join(" ")
  let env_values = envs.values().map(v => v).join(" ")
  let content =
    #| #!/bin/bash
    #| for i in {1..3}; do
    #|   echo "[$i] xxx..."
    #|   sleep 1
    #| done
    $| echo \{env_keys}
  @fs.write_file(temp_file, content, create_mode=CreateOrTruncate)
  let (exit_code, output) = run_command(
    "bash",
    [temp_file],
    cwd="/Users/11048490",
    extra_env=envs,
  )
  inspect(exit_code, content="0")
  // 只验证最后一行
  guard output.trim().split("\n").last() is Some(last_line_output)
  inspect(last_line_output, content=env_values)
}

///|
async test "run_command_with_node" {
  let (exit_code, output) = run_command("node", ["-v"])
  inspect(
    exit_code,
    content=(
      #|0
    ),
  )
  assert_false(output.is_blank())
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
// async fn run_with_output() -> Unit {
//   let (r, w) = @process.read_from_process()
//   defer r.close()
//   let output = @async.with_task_group(group => {
//     group.spawn(() => {
//       while r.read_some() is Some(b) {
//         println(b)
//       }
//     })
//   })
//   let exit_code = @async.with_task_group(group => {
//     group.spawn(() => {
//       let sh =
//         #| for i in {1..3}; do echo "[$i] tick"; sleep 1; done
//       let exit_code = group.spawn(() => {
//         @process.run("bash", ["-c", sh], stdout=w, stderr=w)
//       })
//       exit_code.wait()
//     })
//   })
//   println(exit_code.wait())
//   println(output.wait())
// }

// ///|
// async test "run" {
//   run_with_output()
// }
