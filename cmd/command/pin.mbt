///|
/// 执行项目锁定命令
pub async fn run_pin(tool : @tools.Tool, version : String) -> Unit {
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version)

  // 写入项目配置
  let config_file_path = @tools.write_project_config(tool, version)
  @log.success(
    "已将目录 \{config_file_path} 下的 \{tool} 版本锁定为 \{version}",
  )
}
