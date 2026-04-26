///|
/// 执行卸载命令
pub async fn run_uninstall(tool : @tools.Tool, version : Version) -> Unit {
  let os = @os.get_os_info()
  let version = @tools.get_target_version(os, tool, version.value())

  // 检查是否已安装
  if !@tools.is_installed(tool, version) {
    println("\{tool}@\{version} 未安装")
    return
  }

  // 删除目录
  let dir = @tools.version_dir(tool, version)
  @fs.rmdir(dir, recursive=true)

  println("\{tool}@\{version} 已卸载")
}
