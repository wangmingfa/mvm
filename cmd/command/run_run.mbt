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

  // 解析版本号（支持 lts、latest、20、20.1、20.1.0 等格式）
  let os_info = @os.get_os_info()
  let target_version = if version.is_blank() {
    @log.debug("没有传入版本，从工作目录中获取合适版本")
    // 如果没有传版本，则从当前工作目录获取合适的版本
    guard @tools.get_config(tool~) is Some((_, config)) &&
      config.get_value(tool) is Some(version) else {
      if tool is Node {
        if ["npm", "corepack", "npx"].any(v => v == exec_program) {
          raise fail("请先安装 \{tool}")
        }
        raise fail(
          "此NPM包未安装，请确认当前工作目录是否有可用的Node.js",
        )
      }
      let msg = [
        "未指定",
        @utils.yellow(exec_program),
        "的版本，请使用",
        @utils.yellow("mvm use \{exec_program}@x.y.z"),
        "指定版本，或使用",
        @utils.yellow("mvm use \{exec_program}"),
        "指定为最新版",
      ].join(" ")
      raise fail(msg)
    }
    version
  } else {
    @tools.get_target_version(os_info, tool, version)
  }

  @log.debug("使用 \{tool}@\{target_version} 运行命令: \{to_repr(args)}")

  // 检查是否已安装，未安装则自动安装
  if !@tools.is_installed(tool, target_version) {
    @log.info("\{tool}@\{target_version} 未安装，正在自动安装...")
    run_install(tool, Some(target_version), false, false)
  }

  // 使用统一的 get_program_exe_info 获取程序信息
  let program_info = @tools.get_program_exe_info(
    tool,
    exec_program,
    target_version,
  )
  guard program_info is Some({ name:_, path, version:_, envs, program_exists, tool_exists:_, .. }) else {
    raise fail("找不到要执行的程序 \{exec_program}")
  }
  if !program_exists {
    raise fail("要执行的程序 \{exec_program} 不存在")
  }
  let (exec_program_path, exec_envs) = (path, envs)

  let exec_tool = @tools.Tool::from_string_with_option_result(exec_program)
  let before_run_result = if exec_tool is Some(exec_tool) {
    before_run(exec_tool, exec_program_path, exec_args) catch {
      _ => None
    }
  } else {
    None
  }

  if !@log.is_debug_log_level() {
    @log.clear_all_lines()
  }

  let exit_code = @mvm_cmd.run(exec_program_path, exec_args, extra_env=exec_envs)
  if exit_code != 0 {
    @log.debug("\{tool} 退出码: \{exit_code}")
  } else if exec_tool is Some(exec_tool) {
    // 运行成功之后的处理
    // 比如使用npm安装了全局包
    after_run(before_run_result, exec_tool, exec_program_path, exec_args)
  }
}

///|
async fn before_run(
  exec_tool : @tools.Tool,
  exec_program_path : String,
  exec_args : ArrayView[String],
) -> Map[String, String]? {
  match exec_tool {
    Node => @specials.before_npm_command(exec_program_path, exec_args)
    _ => None
  }
}

///|
async fn after_run(
  before_run_result : Map[String, String]?,
  exec_tool : @tools.Tool,
  exec_program_path : String,
  exec_args : ArrayView[String],
) -> Unit {
  match exec_tool {
    Node =>
      @specials.after_npm_command(
        before_run_result, exec_program_path, exec_args,
      )
    _ => ()
  }
}
