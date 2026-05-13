// 工具名前缀（与 install.sh、executor.sh 保持一致）

///|
async fn run_executor(args : Array[String]) -> Unit {
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
  let tool_name = if tool_name.has_prefix(TOOL_PREFIX) {
    tool_name[TOOL_PREFIX.length():]
  } else {
    tool_name
  }

  let exe_args = args[arg_start_index + 1:]

  let tool = @tools.Tool::from_string(tool_name.to_owned())

  @log.debug("工具名称 \{tool_name}")
  let args_str = exe_args.join(" ")

  let (tool_exe_path, envs) = while true {
    let tool_exe = @tools.get_tool_exe_path(tool)

    @log.debug("运行：\{tool} \{args_str}")

    guard tool_exe
      is Some({ path: tool_exe_path, version, envs, dependent_tool_exe, .. }) else {
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

    if @fs.exists(tool_exe_path) {
      break (tool_exe_path, envs)
    } else {
      let (install_tool, install_version) = if dependent_tool_exe
        is Some({ tool, version, .. }) {
        (tool, version)
      } else {
        (tool, version)
      }
      @log.debug(
        "工具 \{tool} 的可执行文件 \{tool_exe_path} 不存在，正在安装 \{install_tool} ...",
      )
      // 没有安装，提示用户安装或指定版本
      run_install(install_tool, Some(install_version))
    }
  } nobreak {
    ("", {})
  }

  let before_run_result = before_run(tool, tool_exe_path, exe_args)

  let cmd = "\{tool_exe_path} \{args_str}"
  @log.debug("运行：\{cmd}")

  if !@log.is_debug_log_level() {
    // 非debug日志级别，清除之前的内容
    @log.clear_all_lines()
  }

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
