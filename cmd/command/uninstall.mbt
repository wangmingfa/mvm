///|
/// 执行卸载命令
async fn run_uninstall(tool : @tools.Tool, version : String?) -> CommandResult {
  let result = CommandResult::success()
  let versions = get_installed(tool)

  // 如果从配置文件中没有读取到，则从文件夹中读取，防止异常情况下出现两边不一致的情况
  let versions = if versions.is_empty() {
    // 有可能installed.json中没有记录，直接去文件夹看看，有没有需要删除的
    let version_dir = @tools.tool_dir(tool)
    guard @fs.exists(version_dir) is true else {
      @log.warn("未安装 \{tool}，无需卸载")
      return result
    }
    let dirs = []
    for name in @fs.readdir(version_dir) {
      let path = @fs_ext.join_path(version_dir, name)
      if @fs.kind(path) is Directory {
        dirs.push(name)
      }
    }
    dirs
  } else {
    versions
  }

  let remove_versions = []

  for v in versions {
    // 如果version为空，则卸载所有版本
    if version is Some(version) && !@tools.match_version(tool, version, v) {
      continue
    }
    remove_versions.push(v)
    @log.info("卸载 \{tool} \{v}")
    // 删除目录
    let dir = @tools.version_dir(tool, v)
    @fs_ext.remove_dir(dir)
  }

  if remove_versions.is_empty() {
    @log.warn(
      "未安装 \{@tools.tool_version_str(tool, version?)}，无需卸载",
    )
    return result
  }

  // 从已安装中移除
  let removed_versions = remove_installed(tool, remove_versions)

  match removed_versions.length() {
    0 =>
      @log.warn(
        "未安装 \{@tools.tool_version_str(tool, version?)}，无需卸载",
      )
    1 => @log.success("已卸载 \{tool} \{removed_versions[0]}")
    _ => {
      let version_msg = removed_versions.join("、")
      // @log 日志不捕获到 CommandResult
      @log.success("已卸载 \{tool} 版本：\{version_msg}")
    }
  }
  result
}
