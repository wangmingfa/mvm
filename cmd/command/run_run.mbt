///|
/// 执行 run 命令，用指定版本临时运行命令
pub async fn run_run(
  tool : @tools.Tool,
  version : String,
  args : Array[String],
) -> Unit {
  @log.debug("run_run参数 \{tool} \{version} \{to_repr(args)}")
  // 参数不能为空
  if args.is_empty() {
    raise fail(
      "运行的命令不能为空。示例：mvm run node@18 -- node -v",
    )
  }

  let (exec_program, exec_args) = (
    args[0],
    if args.length() > 1 {
      args[1:]
    } else {
      []
    },
  )

  let program_exe_info = @tools.get_program_exe_info(
    tool, exec_program, version,
  )
  let {
    path: exec_program_path,
    version: target_version,
    program_exists,
    tool_exists,
    envs: exec_envs,
    ..,
  } = program_exe_info

  @log.debug("使用 \{tool}@\{target_version} 运行命令: \{to_repr(args)}")
  // 检查工具是否安装，未安装则自动安装
  guard tool_exists is true else {
    @log.info("\{tool}@\{target_version} 未安装，正在自动安装...")
    run_install(tool, Some(target_version), false, false)
  }

  if !program_exists {
    raise fail("要执行的程序 \{exec_program} 不存在")
  }

  let before_run_result = before_run(program_exe_info, exec_args)

  if !@log.is_debug_log_level() {
    @log.clear_all_lines()
  }

  let exit_code = @mvm_cmd.run(
    exec_program_path,
    exec_args,
    extra_env=exec_envs,
  )
  if exit_code != 0 {
    @log.debug("\{tool} 退出码: \{exit_code}")
  } else {
    // 运行成功之后的处理
    // 比如使用npm安装了全局包
    after_run(before_run_result, program_exe_info, exec_args)
  }
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
