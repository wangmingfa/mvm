///|
/// 确保目录存在
pub async fn ensure_dir(dir : String) -> Unit {
  if @fs.exists(dir) {
    return
  }
  @fs.mkdir(dir.to_string_view(), permission=PERMISSION_DIR, recursive=true) catch {
    e => raise fail("创建文件夹 \{dir} 失败，原因：\{e}")
  }
}
