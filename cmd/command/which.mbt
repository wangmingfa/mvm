///|
/// 执行 which 命令，查看当前使用的工具可执行文件路径
async fn run_which(tool : @tools.Tool) -> CommandResult {
  let result = CommandResult::success()
  // 获取配置信息（包含配置文件路径）
  let config_info = @tools.get_config(tool~)
  match config_info {
    Some((config_path, config)) => {
      guard config.get_value(tool) is Some(version) else {
        // 未在配置文件中找到版本信息
        raise fail(
          @i18n.t("which.version_not_found_in_config", args={
            "config_path": @utils.yellow(config_path),
            "tool": tool.to_string(),
          }),
        )
      }
      // 通过已有的公共 API 获取可执行文件路径
      let { path: exe_path, .. } = @tools.get_program_exe_info(
        tool,
        tool.to_string(),
        version,
      )
      let mvm_home = @tools.mvm_home()
      // 全局/项目
      let source_label = if config_path.has_prefix(mvm_home) {
        @i18n.t("which.global")
      } else {
        @i18n.t("which.project")
      }
      let installed = @fs.exists(exe_path)
      // 未安装
      let not_installed_label = @utils.yellow(@i18n.t("which.not_installed"))
      if installed {
        print_to(result, "\{exe_path} (\{source_label}: \{config_path})")
      } else {
        print_to(
          result,
          "\{exe_path} (\{source_label}: \{config_path}) - \{not_installed_label}",
        )
        // 请使用 mvm install 安装该版本
        print_to(
          result,
          @i18n.t("which.install_hint", args={
            "tool": tool.to_string(),
            "version": version,
          }),
        )
      }
      result
    }
    None =>
      // 未找到版本配置
      raise fail(
        @i18n.t("which.no_version_config", args={ "tool": tool.to_string() }),
      )
  }
}
