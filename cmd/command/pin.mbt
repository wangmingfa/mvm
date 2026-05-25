///|
/// 执行项目锁定命令
async fn run_pin(tool : @tools.Tool, version : String) -> CommandResult {
  let result = CommandResult::success()
  let version = @tools.get_target_version(tool, version)

  // 写入项目配置
  let config_file_path = @tools.write_project_config(tool, version)
  // 已锁定项目版本
  @log.success(
    @i18n.t("pin.set_project_with_path", args={ "path": config_file_path, "tool": tool.to_string(), "version": version }),
  )
  result
}
