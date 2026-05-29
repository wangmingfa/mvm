///|
/// 执行全局版本设置命令
async fn run_use(tool : @tools.Tool, version : String?) -> CommandResult {
  let result = CommandResult::success()
  let version = if version is Some(version) { version } else { "" }
  let version = @tools.get_target_version(tool, version)

  let _ = @tools.write_global_config(tool, version)

  // 已设置全局版本
  @log.success(
    @i18n.t("use.set_global", args={
      "tool": tool.to_string(),
      "version": version,
    }),
  )
  result
}
