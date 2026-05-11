///|
/// 执行 run 命令，用指定版本临时运行命令
pub async fn run_run(
  tool : @tools.Tool,
  version : String,
  args : Array[String],
) -> Unit {
  // 解析版本号（支持 lts、latest、20、20.1、20.1.0 等格式）
  let os_info = @os.get_os_info()
  let target_version = @tools.get_target_version(os_info, tool, version)

  // 如果第一个参数与工具名重复（如 mvm run node@18 -- node -v），跳过它
  let tool_name = tool.to_string()
  let args = if args.length() > 0 && args[0] == tool_name {
    args[1:]
  } else {
    args
  }

  @log.debug("使用 \{tool}@\{target_version} 运行命令: \{args}")

  // 检查是否已安装，未安装则自动安装
  if !@tools.is_installed(tool, target_version) {
    @log.info("\{tool}@\{target_version} 未安装，正在自动安装...")
    run_install(tool, Some(target_version))
  }

  // 获取可执行文件路径
  let exe_path = @tools.get_exe_path_for_version(tool, target_version)
  if !@fs.exists(exe_path) {
    @log.error(
      "\{tool}@\{target_version} 的可执行文件不存在：\{@utils.yellow(exe_path)}",
    )
    return
  }

  let args_str = args.join(" ")
  @log.info("运行：\{exe_path} \{args_str}")

  if !@log.is_debug_log_level() {
    @log.clear_all_lines()
  }

  let exit_code = @mvm_cmd.run(exe_path, args)
  if exit_code != 0 {
    @log.debug("\{tool} 退出码: \{exit_code}")
  }
}
