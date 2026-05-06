// 工具名前缀（与 install.sh、executor.sh 保持一致）

///|
const PREFIX = "f_"

///|
async fn run_executor(args : Array[String]) -> Unit {
  // 进入备用屏幕，防止打印的日志影响本身的命令
  @log.enter_alternate_screen_on_release_mode()

  @log.debug("executor参数: \{args}")
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
  // 前缀硬编码，与 install.sh、executor.sh 保持一致
  let tool_name = if tool_name.has_prefix(PREFIX) {
    tool_name[PREFIX.length():]
  } else {
    tool_name
  }

  let exe_args = args[arg_start_index + 1:]

  let tool = @tools.Tool::from_string(tool_name.to_owned()) catch {
    // 处理手动安装的第三方包，比如npm install -g安装的包
    _ => {
      @specials.run_3rd_party_executor(tool_name, exe_args)
      return
    }
  }

  @log.debug("工具名称 \{tool_name}")
  let args_str = exe_args.join(" ")
  let result = @tools.get_tool_exe_path(tool)

  @log.debug("运行：\{tool} \{args_str}")

  guard result is Some((tool_exe_path, version, envs)) else {
    let use_command = @utils.yellow("use")
    let pin = @utils.yellow("pin")
    @log.error(
      "没有指定 \{@utils.yellow(tool_name)} 的版本，请先使用 \{use_command} 或 \{pin} 指定版本",
    )
    return
  }

  @log.debug(
    "使用 \{tool} 的 \{version} 版本运行命令，额外环境变量：\{envs}",
  )

  if !@fs.exists(tool_exe_path) {
    @log.debug(
      "工具 \{tool} 的可执行文件 \{tool_exe_path} 不存在，正在安装...",
    )
    // 没有安装，提示用户安装或指定版本
    run_install(tool, Some(version))
  }

  let before_run_result = before_run(tool, tool_exe_path, exe_args)

  let cmd = "\{tool_exe_path} \{args_str}"
  @log.debug("运行：\{cmd}")

  // 退出备用屏幕
  @log.exit_alternate_screen_on_release_mode()

  let exit_code = @mvm_cmd.run(tool_exe_path, exe_args, extra_env=envs)

  if exit_code == 0 {
    // 运行成功之后的处理
    // 比如使用npm安装了全局包
    after_run(before_run_result, tool, tool_exe_path, exe_args)
  }
}

///|
async fn before_run(
  tool : @tools.Tool,
  tool_exe_path : String,
  args : ArrayView[String],
) -> Map[String, String]? {
  match tool {
    Npm => @specials.before_npm_command(tool_exe_path, args)
    _ => None
  }
}

///|
async fn after_run(
  before_run_result : Map[String, String]?,
  tool : @tools.Tool,
  tool_exe_path : String,
  args : ArrayView[String],
) -> Unit {
  match tool {
    Npm => @specials.after_npm_command(before_run_result, tool_exe_path, args)
    _ => ()
  }
}
