///|
async fn main {
  let args = @env.args()
  guard args.get(1) is Some(exe_name) else {
    @log.error("命令不合法")
    return
  }
  let exe_name = @fs_ext.get_path_name(exe_name)
  guard exe_name.split(".").next() is Some(tool_name)
  let tool = @tools.Tool::from_string(tool_name.to_string())
  let exe_args = args[2:]
  let args_str = exe_args.join(" ")
  let result = @tools.get_tool_exe_path(tool)

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
    @command.run_install(tool, @command.Version::new(version))
  }

  let cmd = "\{tool_exe_path} \{args_str}"
  @log.info("运行：\{cmd}")
  let _ = @process.run(tool_exe_path, exe_args)
}
