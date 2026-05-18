///|
/// 执行 which 命令，查看当前使用的工具可执行文件路径
async fn run_which(tool : @tools.Tool) -> CommandResult {
  let result = CommandResult::success()
  // 获取配置信息（包含配置文件路径）
  let config_info = @tools.get_config(tool~)
  match config_info {
    Some((config_path, config)) => {
      guard config.get_value(tool) is Some(version) else {
        raise fail(
          "未在配置文件 \{@utils.yellow(config_path)} 中找到 \{tool} 的版本信息",
        )
      }
      // 通过已有的公共 API 获取可执行文件路径
      let { path: exe_path, .. } = @tools.get_program_exe_info(
        tool,
        tool.to_string(),
        version,
      )
      let mvm_home = @tools.mvm_home()
      let source_label = if config_path.has_prefix(mvm_home) {
        "全局"
      } else {
        "项目"
      }
      let installed = @fs.exists(exe_path)
      let not_installed_label = @utils.yellow("未安装")
      if installed {
        print_to(result, "\{exe_path} (\{source_label}: \{config_path})")
      } else {
        print_to(
          result,
          "\{exe_path} (\{source_label}: \{config_path}) - \{not_installed_label}",
        )
        print_to(result, "请使用 mvm install \{tool}@\{version} 安装该版本")
      }
      result
    }
    None =>
      raise fail(
        "未找到 \{tool} 的版本配置，请先使用 mvm use 或 mvm pin 指定版本",
      )
  }
}
