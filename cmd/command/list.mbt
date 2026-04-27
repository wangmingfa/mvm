///|
/// 执行查看版本命令
pub async fn run_list(tool : @tools.Tool?) -> Unit {
  // 如果没有指定tool，则查全部
  let tools = if tool is Some(tool) { [tool] } else { @tools.Tool::all() }

  for tool in tools {
    let versions = get_installed(tool)
    println("\{tool}:")
    if versions.is_empty() {
      println("  (暂无)")
    } else {
      for version in versions {
        println("  - \{version}")
      }
    }
  }
}
