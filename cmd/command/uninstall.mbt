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
      // 未安装该工具
      @log.warn(
        @i18n.t("uninstall.not_installed_tool", args={
          "tool": tool.to_string(),
        }),
      )
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
    // 正在卸载
    @log.info(
      @i18n.t("uninstall.uninstalling_version", args={
        "tool": tool.to_string(),
        "version": v,
      }),
    )
    // 删除目录
    let dir = @tools.version_dir(tool, v)
    @fs_ext.remove_dir(dir)
  }

  if remove_versions.is_empty() {
    // 未安装该版本
    @log.warn(
      @i18n.t("uninstall.not_installed_version", args={
        "version_str": @tools.tool_version_str(tool, version?),
      }),
    )
    return result
  }

  // 从已安装中移除
  let removed_versions = remove_installed(tool, remove_versions)

  match removed_versions.length() {
    0 =>
      // 未安装该版本
      @log.warn(
        @i18n.t("uninstall.not_installed_version", args={
          "version_str": @tools.tool_version_str(tool, version?),
        }),
      )
    1 =>
      // 已卸载单个版本
      @log.success(
        @i18n.t("uninstall.uninstall_success", args={
          "tool": tool.to_string(),
          "version": removed_versions[0],
        }),
      )
    _ => {
      let version_msg = removed_versions.join("、")
      // 已卸载多个版本
      @log.success(
        @i18n.t("uninstall.uninstall_multi_success", args={
          "tool": tool.to_string(),
          "versions": version_msg,
        }),
      )
    }
  }
  result
}
