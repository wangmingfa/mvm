///|
/// 执行移除全局版本命令
async fn run_unuse(tool : @tools.Tool) -> CommandResult {
  let result = CommandResult::success()
  let _ = @tools.remove_global_config(tool)

  // @log 日志不捕获到 CommandResult
  @log.success("已移除全局 \{tool} 版本设置")
  result
}
