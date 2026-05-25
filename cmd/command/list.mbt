///|
/// 执行查看版本命令
async fn run_list(tool : @tools.Tool?) -> CommandResult {
  let result = CommandResult::success()
  // 如果没有指定tool，则查全部
  let tools = if tool is Some(tool) {
    [tool]
  } else {
    @tools.Tool::installable_tools()
  }

  for tool in tools {
    let versions = get_installed(tool)
    let cwd_config = @tools.get_config(tool~, fallback_to_global_config=false)
    let cwd_tool_version = if cwd_config is Some(c) {
      c.1.get_value(tool)
    } else {
      None
    }
    let global_config = @tools.get_config(
      tool~,
      dir=@tools.mvm_home(),
      search_upwards=false,
    )
    let global_tool_version = if global_config is Some(c) {
      c.1.get_value(tool)
    } else {
      None
    }

    // 当前目录版本
    @log.debug(
      @i18n.t("list.debug_cwd_version", args={ "tool": tool.to_string(), "version": @utils.option_to_string(cwd_tool_version) }),
    )
    // 全局版本
    @log.debug(
      @i18n.t("list.debug_global_version", args={ "tool": tool.to_string(), "version": @utils.option_to_string(global_tool_version) }),
    )

    // 工具标题
    print_to(result, "\{@i18n.t("list.tool_header", args={ "tool": tool.to_string() })}")
    if versions.is_empty() {
      // 暂无
      print_to(result, "  \{@i18n.t("list.no_versions")}")
    } else {
      for version in versions {
        let version_tips = if cwd_tool_version is Some(v) && v == version {
          // 当前目录
          " \{@i18n.t("list.cwd_marker")}"
        } else if global_tool_version is Some(v) && v == version {
          // 全局
          " \{@i18n.t("list.global_marker")}"
        } else {
          ""
        }
        print_to(result, "  - \{version}\{version_tips}")
      }
    }
  }
  result
}
