///|
/// 执行项目锁定命令
pub async fn run_pin(tool : @lib.Tool, version : @lib.Version) -> Unit {
  let os = @os.get_os_info()
  let version = get_target_version(os, tool, version.value())

  // 检查版本是否已安装
  if !@lib.is_installed(tool, version) {
    println(
      "\{tool}@\{version} 未安装，请先运行: mvm install \{tool}@\{version}",
    )
    return
  }

  // 写入项目配置
  @lib.write_project_config(tool, version)
  println("已将项目 \{tool} 版本锁定为 \{version}")
  println("配置文件: .mvmrc")
}
