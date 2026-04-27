///|
/// 执行临时切换命令
pub async fn run_use(tool : @tools.Tool, version : String) -> Unit {
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version)

  let _ = @tools.write_global_config(tool, version)

  @log.success("已将全局 \{tool} 版本设置为 \{version}")
}
