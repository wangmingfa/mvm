///|
/// 执行移除全局版本命令
async fn run_unuse(tool : @tools.Tool) -> CommandResult {
  let result = CommandResult::success()
  let _ = @tools.remove_global_config(tool)

  // 已移除全局版本设置
  @log.success(@i18n.t("unuse.removed_global", args={ "tool": tool.to_string() }))
  result
}
