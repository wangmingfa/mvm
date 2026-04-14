///|
/// 执行卸载命令
pub async fn run_uninstall(tool : @lib.Tool, version : @lib.Version) -> Unit {
  let version = get_target_version(tool, version.value())

  // 检查是否已安装
  if !@lib.is_installed(tool, version) {
    println("\{tool}@\{version} 未安装")
    return
  }

  // 删除目录
  let dir = @lib.version_dir(tool, version)
  @fs.rmdir(dir, recursive=true)

  println("\{tool}@\{version} 已卸载")
}
