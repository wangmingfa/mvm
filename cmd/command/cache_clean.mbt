///|
/// 执行 cache clean 命令，清理缓存和临时文件
async fn run_cache_clean() -> Unit {
  let cache_dir = @tools.cache_dir()
  let temp_dir = @tools.temp_dir()

  let mut cleaned = false

  // 清理缓存目录
  if @fs.exists(cache_dir) {
    @fs_ext.remove_dir(cache_dir)
    println("已清理缓存目录: \{cache_dir}")
    cleaned = true
  }

  // 清理临时目录
  if @fs.exists(temp_dir) {
    @fs_ext.remove_dir(temp_dir)
    println("已清理临时目录: \{temp_dir}")
    cleaned = true
  }

  if !cleaned {
    println("缓存目录为空，无需清理")
  }
}
