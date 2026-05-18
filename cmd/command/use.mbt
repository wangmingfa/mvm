///|
/// 执行全局版本设置命令
async fn run_use(tool : @tools.Tool, version : String?) -> CommandResult {
  let result = CommandResult::success()
  let version = if version is Some(version) { version } else { "" }
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version)

  let _ = @tools.write_global_config(tool, version)

  // @log 日志不捕获到 CommandResult（仅打印到控制台）
  @log.success("已将全局 \{tool} 版本设置为 \{version}")
  result
}
