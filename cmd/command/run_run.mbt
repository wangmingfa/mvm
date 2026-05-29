///|
/// 执行 run 命令，用指定版本临时运行命令
/// 使用 C FFI run_with_output 同时流式输出到控制台并捕获 stdout
async fn run_run(
  tool : @tools.Tool,
  version : String,
  args : Array[String],
) -> CommandResult {
  @log.debug("run_run参数 \{tool} \{version} \{to_repr(args)}")
  // 参数不能为空
  if args.is_empty() {
    // 运行的命令不能为空
    raise fail(@i18n.t("run.empty_command"))
  }

  let (exec_program, exec_args) = (
    args[0],
    if args.length() > 1 {
      args[1:]
    } else {
      []
    },
  )

  let mut try_install = true

  let program_exe_info = while true {
    @log.debug(@i18n.t("run.debug_fetching_program_info"))
    let program_exe_info = @tools.get_program_exe_info(
      tool, exec_program, version,
    )
    @log.debug(@i18n.t("run.debug_program_info", args={"info": to_repr(program_exe_info).to_string()}))
    let {
      path: exec_program_path,
      version: target_version,
      program_exists,
      tool_exists,
      ..,
    } = program_exe_info

    // 使用tool@version运行命令
    @log.debug(
      @i18n.t("run.debug_running_command", args={
        "tool": tool.to_string(),
        "version": target_version,
        "path": exec_program_path,
        "args": to_repr(args).to_string(),
      }),
    )
    // 检查工具是否安装，未安装则自动安装
    if !tool_exists {
      if try_install {
        try_install = false
        // 非 TTY 环境不支持自动安装
        if !@stdio.is_stdout_tty() {
          // 非 TTY 环境不支持自动安装
          raise fail(@i18n.t("run.not_tty_environment"))
        }
        // 尝试安装
        @log.info(
          @i18n.t("run.auto_installing", args={
            "tool": tool.to_string(),
            "version": target_version,
          }),
        )
        let install_result = run_install(
          tool,
          Some(target_version),
          false,
          false,
        )
        if !install_result.is_success() {
          // 安装失败
          raise fail(
            install_result.error.unwrap_or(
              @i18n.t("run.install_failed_fallback"),
            ),
          )
        }
        continue
      } else {
        // 安装后，工具还是不存在
        raise fail(
          @i18n.t("run.install_tool_failed", args={
            "tool": tool.to_string(),
            "version": target_version,
          }),
        )
      }
    }
    // 检查要运行的程序是否存在
    if !program_exists {
      // 要执行的程序不存在
      raise fail(
        @i18n.t("run.program_not_exists", args={
          "program": exec_program,
          "path": exec_program_path,
        }),
      )
    }
    break program_exe_info
  } nobreak {
    // 无法运行命令
    raise fail(@i18n.t("run.cannot_run_command"))
  }

  let before_run_result = before_run(program_exe_info, exec_args)

  if !@log.is_debug_log_level() {
    @log.clear_all_lines()
  }

  let { path: exec_program_path, envs: exec_envs, .. } = program_exe_info

  let (exit_code, output) = if @log.is_debug() {
    @mvm_cmd.run_with_output(exec_program_path, exec_args, extra_env=exec_envs)
  } else {
    (@process.run(exec_program_path, exec_args, extra_env=exec_envs), "")
  }

  let result = CommandResult::success_with_output(output.text())
  result.exit_code = exit_code

  if exit_code != 0 {
    @log.debug("\{tool} 退出码: \{exit_code}")
  } else {
    // 运行成功之后的处理
    // 比如使用npm安装了全局包
    after_run(before_run_result, program_exe_info, exec_args)
  }

  result
}

///|
async fn before_run(
  get_program_exe_info : @tools.ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Map[String, String]? {
  let { tool, name: program, path: program_path, .. } = get_program_exe_info
  match (tool, program) {
    (Node, "npm") => @specials.before_npm_command(program_path, exec_args)
    _ => None
  }
}

///|
async fn after_run(
  before_run_result : Map[String, String]?,
  get_program_exe_info : @tools.ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Unit {
  let { tool, name: program, path: program_path, .. } = get_program_exe_info
  match (tool, program) {
    (Node, "npm") =>
      @specials.after_npm_command(before_run_result, program_path, exec_args)
    _ => ()
  }
}
