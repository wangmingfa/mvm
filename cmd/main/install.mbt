///|
using @fs_ext {ensure_dir}

///|
/// 执行安装命令
pub async fn run_install(tool : @tools.Tool, version : Version) -> Unit {
  let os_info = @os.get_os_info()
  let version = @tools.get_target_version(os_info, tool, version.value())

  // 检查是否已安装
  if @tools.is_installed(tool, version) {
    println("\{tool}@\{version} 已安装")
    return
  }

  // npm 随 node 安装
  if tool is @tools.Npm {
    println("npm 会随 node 自动安装，请先安装 node")
    return
  }

  // 确保目录存在
  ensure_dir(@tools.tool_dir(tool))

  // 获取下载 URL
  let (url, root_path_depth) = @tools.get_download_url(os_info, tool, version)
  if url.is_blank() {
    println("无法获取下载地址")
    return
  }

  // 下载文件
  let tmp_dir = "\{@tools.mvm_home()}/tmp-\{tool}-\{version}"
  ensure_dir(tmp_dir)
  let ext = if url.has_suffix(".tar.gz") {
    "tar.gz"
  } else if url.has_suffix(".tar.xz") {
    "tar.xz"
  } else {
    "zip"
  }
  let archive_file = "\{tmp_dir}/\{tool}-\{version}.\{ext}"

  if !download_file(url, archive_file) {
    return
  }

  // 解压到临时目录
  let extract_dir = "\{tmp_dir}/extract-\{tool}-\{version}"
  ensure_dir(extract_dir)

  if !extract_file(archive_file, extract_dir) {
    return
  }

  let mut src_dir = extract_dir
  let mut find_sub_dir_count : UInt = 0
  while find_sub_dir_count < root_path_depth {
    let entries = @fs.readdir(src_dir)
    if entries.is_empty() {
      raise fail(
        "无法从 \{extract_dir} 找到深度为 \{root_path_depth} 的目录",
      )
    }
    src_dir = @fs_ext.join_path(src_dir, entries[0])
    find_sub_dir_count += 1
  }
  // 移动到最终目录
  let final_dir = @tools.version_dir(tool, version)
  println("目录 \{src_dir} 移动到 \{final_dir}")
  @fs_ext.mv(src_dir, final_dir, include_root=false)

  // 清理临时文件
  @fs.rmdir(tmp_dir, recursive=true)

  println("\{tool}@\{version} 安装成功")
}

///|
/// 下载文件
pub async fn download_file(url : String, dest : String) -> Bool {
  println("正在下载: \{url}")
  println("保存到：\{dest}")
  @download.download(url, dest, dest_is_file=true) catch {
    e => {
      println("下载失败，原因：")
      println(e)
      return false
    }
  }
  true
}

///|
/// 解压文件
pub async fn extract_file(file : String, dest : String) -> Bool {
  println("正在解压到 \{dest} ...")
  let (code, data) = match file {
    f if f.has_suffix(".tar.gz") =>
      @process.collect_output_merged("tar", ["-xzf", f, "-C", dest])
    f if f.has_suffix(".tar.xz") =>
      @process.collect_output_merged("tar", ["-xJf", f, "-C", dest])
    f if f.has_suffix(".zip") =>
      @process.collect_output_merged("unzip", ["-q", "-o", f, "-d", dest])
    _ => {
      println("未知的压缩格式")
      return false
    }
  }
  match code {
    0 => true
    _ => {
      println("解压失败，原因：")
      println(data.text())
      false
    }
  }
}
