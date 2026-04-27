///|
/// 执行卸载命令
pub async fn run_uninstall(tool : @tools.Tool, version : Version) -> Unit {
  let version = version.0
  let versions = get_installed(tool)

  if versions.is_empty() {
    @log.warn("未安装 \{tool}，无需卸载")
    return
  }

  let remove_versions = []

  for v in versions {
    if !@tools.match_version(tool, version, v) {
      continue
    }
    remove_versions.push(v)
    @log.info("卸载 \{tool} \{v}")
    // 删除目录
    let dir = @tools.version_dir(tool, v)
    @fs.rmdir(dir, recursive=true)
  }

  if remove_versions.is_empty() {
    @log.warn("未安装 \{tool}@\{version}，无需卸载")
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
