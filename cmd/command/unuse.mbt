///|
/// 执行移除全局版本命令
async fn run_unuse(tool : @tools.Tool) -> Unit {
  let _ = @tools.remove_global_config(tool)

  @log.success("已移除全局 \{tool} 版本设置")
}
