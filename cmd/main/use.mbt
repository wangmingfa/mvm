///|
/// 执行临时切换命令
pub async fn run_use(tool : @tools.Tool, version : Version) -> Unit {
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version.value())

  // 检查版本是否已安装
  if !@tools.is_installed(tool, version) {
    println(
      "\{tool}@\{version} 未安装，请先运行: mvm install \{tool}@\{version}",
    )
    return
  }

  println("已切换 \{tool} 至 \{version}")
  println(
    "注意: 此切换仅在当前 shell 有效，永久切换请使用 mvm pin",
  )
}
