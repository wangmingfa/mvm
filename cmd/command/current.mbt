///|
/// 执行 current 命令，查看当前使用的工具版本
async fn run_current(tool : @tools.Tool?) -> Unit {
  let tools = if tool is Some(tool) {
    [tool]
  } else {
    @tools.Tool::installable_tools()
  }

  // 计算最大工具名长度，用于对齐
  let mut max_name_len = 0
  for t in tools {
    let len = t.to_string().length()
    if len > max_name_len {
      max_name_len = len
    }
  }

  for tool in tools {
    let tool_name = tool.to_string()
    let padding = " ".repeat(max_name_len - tool_name.length())
    let label = "\{tool_name}\{padding}"
    let config_info = @tools.get_config(tool~)
    match config_info {
      Some((config_path, config)) => {
        guard config.get_value(tool) is Some(version) else {
          println("\{label}: (未设置)")
          continue
        }
        let mvm_home = @tools.mvm_home()
        let source_label = if config_path.has_prefix(mvm_home) {
          "全局"
        } else {
          "项目"
        }
        let installed = @tools.is_installed(tool, version)
        let not_installed_label = @utils.yellow("未安装")
        if installed {
          println("\{label}: \{@utils.green(version)} (\{source_label})")
        } else {
          println(
            "\{label}: \{version} (\{source_label}) \{not_installed_label}",
          )
        }
      }
      None => println("\{label}: (未设置)")
    }
  }
}
