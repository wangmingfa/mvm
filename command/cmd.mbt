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
/// Windows 自带命令白名单，这些命令可以直接执行，无需通过 PowerShell 包装
/// 包括：系统内置命令（cmd 内建）、Windows 10+ 自带的独立工具等
fn is_windows_native_cmd(cmd : StringView) -> Bool {
  let native_cmds = [
    // 压缩/解压工具（Windows 10+ 自带）
    "tar", "tar.exe",
    // 网络工具（Windows 10+ 自带）
     "curl", "curl.exe", "wget", "wget.exe",
    // 系统内置命令
     "cmd", "where", "echo", "type", "copy", "move", "del", "mkdir", "rmdir", "xcopy",
    "robocopy", "findstr", "attrib", "icacls",
    // 网络诊断
     "ping", "ipconfig", "net", "netsh", "nslookup",
    // 包管理
     "winget",
    // 证书工具
     "certutil",
    // PowerShell 自身（避免嵌套）
     "powershell", "powershell.exe", "pwsh", "pwsh.exe",
    // 解压工具（可能通过第三方安装）
     "unzip", "unzip.exe", "7z", "7z.exe",
  ]
  let cmd_lower = cmd.to_owned().to_lower()
  native_cmds.any(c => c == cmd_lower)
}

///|
fn get_cmd_and_args(
  cmd : StringView,
  args : ArrayView[String],
) -> (StringView, ArrayView[String]) {
  // 在 Windows 下，PowerShell 专属命令需要通过 powershell -Command 包装
  // 系统自带命令（白名单）可以直接执行，无需包装
  let os = @os.get_os_name()
  match os {
    Windows =>
      if is_windows_native_cmd(cmd) {
        (cmd, args)
      } else {
        ("powershell", ["-Command", join_args([cmd.to_owned(), ..args])])
      }
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
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &@process.ProcessInput,
  stdout? : &@process.ProcessOutput,
  stderr? : &@process.ProcessOutput,
  cwd? : StringView,
) -> Int {
  let (cmd, args) = get_cmd_and_args(cmd, args)
  let arg_str = join_args(args)
  @log.debug(
    @i18n.t("cmd.debug_running", args={ "cmd": "\{cmd}", "args": arg_str }),
  )
  @process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
  )
}

///|
/// 执行命令并收集合并的 stdout/stderr 输出
pub async fn collect_output_merged(
  cmd : StringView,
  args : ArrayView[String],
) -> (Int, &@io.Data) {
  let (cmd, args) = get_cmd_and_args(cmd, args)
  let arg_str = join_args(args)
  @log.debug(
    @i18n.t("cmd.debug_running", args={ "cmd": "\{cmd}", "args": arg_str }),
  )
  @process.collect_output_merged(cmd, args.to_owned())
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
pub async fn run_with_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &@process.ProcessInput,
  cwd? : StringView,
) -> (Int, &@io.Data) {
  let cmd_str = join_args([cmd.to_owned(), ..args])
  @log.debug(
    @i18n.t("cmd.debug_running_cmd", args={ "cmd": @debug.to_string(cmd_str) }),
  )
  let (r, w) = @process.read_from_process()
  let (exit_code, output) = @async.with_task_group(group => {
    defer r.close()
    let output = group.spawn(() => {
      let buffer = Buffer()
      while r.read_some() is Some(b) {
        let (bytes, str) = gbk_to_utf8(b)
        @stdio.print(str)
        @stdio.flush_stdout()
        buffer.write_bytes(bytes)
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
    // let (exit_code, output) = if exit_code.try_wait() is Some(exit_code) {
    //   (exit_code, output.wait())
    // } else {
    //   output.cancel()
    //   (1, b"Failed")
    // }
    (exit_code.wait(), output.wait())
  })
  (exit_code, output)
}

///|
/// 处理windows下使用GBK编码，导致日志乱码
#cfg(platform="windows")
fn gbk_to_utf8(bytes : Bytes) -> (Bytes, String) {
  let str = @utf8.decode(bytes) catch { _ => @ffi.gbk_to_utf8(bytes) }
  (@utf8.encode(str), str)
}

///|
#cfg(not(platform="windows"))
fn gbk_to_utf8(bytes : Bytes) -> (Bytes, String) {
  // unix没有支持gbk转utf8
  return (bytes, @utf8.decode_lossy(bytes))
}

///|
test "" {
  let _ = @ffi.string_to_c_bytes("")
}
