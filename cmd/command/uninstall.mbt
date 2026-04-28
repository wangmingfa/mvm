///|
/// 执行卸载命令
pub async fn run_uninstall(tool : @tools.Tool, version : String?) -> Unit {
  let versions = get_installed(tool)

  if versions.is_empty() {
    @log.warn("未安装 \{tool}，无需卸载")
    return
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
    let version_msg = if version is Some(v) { "@\{v}" } else { "" }
    @log.warn("未安装 \{tool}\{version_msg}，无需卸载")
    return
  }

  // 从已安装中移除
  let removed_versions = remove_installed(tool, remove_versions)

  match removed_versions.length() {
    0 => @log.warn("未安装 \{tool}@\{version}，无需卸载")
    1 => @log.success("已卸载 \{tool} \{removed_versions[0]}")
    _ => {
      let version_msg = removed_versions.join("、")
      @log.success("已卸载 \{tool} 版本：\{version_msg}")
    }
  }
}
