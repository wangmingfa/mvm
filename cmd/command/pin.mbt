///|
/// 执行项目锁定命令
pub async fn run_pin(tool : @tools.Tool, version : Version) -> Unit {
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version.value())

  // 写入项目配置
  let config_file_path = @tools.write_project_config(tool, version)
  println("已将项目的 \{tool} 版本锁定为 \{version}")
  println("配置文件: \{config_file_path}")
}
