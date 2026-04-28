///|
async fn main {
  @log.debug("参数: \{@env.args()}")
  guard @env.current_dir() is Some(cwd)
  @log.debug("当前目录：\{cwd}")

  run() catch {
    e => @log.println_error(e)
  }
}

///|
async fn run() -> Unit {
  let args = @env.args()
  // 兼容开发环境和生产环境
  // 开发环境：从下标1开始，因为需要传入具体的工具名称
  // 生产环境：从下标0开始，工具名称已在软连接的名称上面
  let arg_start_index = if args[0].contains("/cmd/exe") { 1 } else { 0 }
  guard args.get(arg_start_index) is Some(exe_name) else {
    @log.error("命令不合法")
    return
  }
  let exe_name = @fs_ext.get_path_name(exe_name)
  guard exe_name.split(".").next() is Some(tool_name)
  let tool_name = if tool_name.has_prefix("f") {
    tool_name[1:]
  } else {
    tool_name
  }

  @log.debug("工具名称 \{tool_name}")

  let tool = @tools.Tool::from_string(tool_name.to_string())
  let exe_args = args[arg_start_index + 1:]
  let args_str = exe_args.join(" ")
  let result = @tools.get_tool_exe_path(tool)

  @log.debug("运行：\{tool} \{args_str}")

  guard result is Some((tool_exe_path, version)) else {
    let use_command = @utils.yellow("use")
    let pin = @utils.yellow("pin")
    // println("config: \{@tools.get_config(tool~)}")
    @log.error(
      "没有指定 \{@utils.yellow(tool_name)} 的版本，请先使用 \{use_command} 或 \{pin} 指定版本",
    )
    return
  }
  if !@fs.exists(tool_exe_path) {
    // 没有安装，提示用户安装或指定版本
    @command.run_install(tool, Some(version))
  }

  let cmd = "\{tool_exe_path} \{args_str}"
  @log.debug("运行：\{cmd}")
  let _ = @process.run(tool_exe_path, exe_args)
}
