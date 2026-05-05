///|
/// 执行查看版本命令
pub async fn run_list(tool : @tools.Tool?) -> Unit {
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

    @log.debug(
      "\{tool} 当前目录版本 \{@utils.option_to_string(cwd_tool_version)}",
    )
    @log.debug(
      "\{tool} 全局版本 \{@utils.option_to_string(global_tool_version)}",
    )

    println("\{tool}:")
    if versions.is_empty() {
      println("  (暂无)")
    } else {
      for version in versions {
        let version_tips = if cwd_tool_version is Some(v) && v == version {
          " (当前目录)"
        } else if global_tool_version is Some(v) && v == version {
          " (全局)"
        } else {
          ""
        }
        println("  - \{version}\{version_tips}")
      }
    }
  }
}
