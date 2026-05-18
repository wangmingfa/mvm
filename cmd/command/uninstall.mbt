///|
/// 执行卸载命令
async fn run_uninstall(tool : @tools.Tool, version : String?) -> CommandResult {
  let result = CommandResult::success()
  let versions = get_installed(tool)

  if versions.is_empty() {
    // @log 日志不捕获到 CommandResult
    @log.warn("未安装 \{tool}，无需卸载")
    return result
  }

  let remove_versions = []

  for v in versions {
    // 如果version为空，则卸载所有版本
    if version is Some(version) && !@tools.match_version(tool, version, v) {
      continue
    }
    remove_versions.push(v)
    // @log 日志不捕获到 CommandResult
    @log.info("卸载 \{tool} \{v}")
    // 删除目录
    let dir = @tools.version_dir(tool, v)
    @fs_ext.remove_dir(dir)
  }

  if remove_versions.is_empty() {
    let version_msg = if version is Some(v) { "@\{v}" } else { "" }
    // @log 日志不捕获到 CommandResult
    @log.warn("未安装 \{tool}\{version_msg}，无需卸载")
    return result
  }

  // 从已安装中移除
  let removed_versions = remove_installed(tool, remove_versions)

  match removed_versions.length() {
    0 =>
      // @log 日志不捕获到 CommandResult
      @log.warn(
        "未安装 \{tool}@\{@utils.option_to_string(version)}，无需卸载",
      )
    1 =>
      // @log 日志不捕获到 CommandResult
      @log.success("已卸载 \{tool} \{removed_versions[0]}")
    _ => {
      let version_msg = removed_versions.join("、")
      // @log 日志不捕获到 CommandResult
      @log.success("已卸载 \{tool} 版本：\{version_msg}")
    }
  }
  result
}
