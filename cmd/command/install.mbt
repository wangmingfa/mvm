///|
using @fs_ext {ensure_dir}

///|
/// 执行安装命令
pub async fn run_install(tool : @tools.Tool, version : String?) -> Unit {
  // 如果version为空，则默认为lts
  let version = if version is Some(version) { version } else { "" }
  let os_info = @os.get_os_info()
  let version = @tools.get_target_version(os_info, tool, version)

  // 检查是否已安装
  if @tools.is_installed(tool, version) {
    @log.warn("\{tool}@\{version} 已安装")
    // 修复installed.json里面缺失已安装的版本的问题
    add_installed(tool, version)
    return
  }

  // npm 随 node 安装
  if tool is @tools.Tool::Npm {
    println("npm 会随 node 自动安装，请先安装 node")
    return
  }

  @log.info("安装 \{@utils.yellow(tool)} \{@utils.yellow(version)}")

  // 确保目录存在
  ensure_dir(@tools.tool_dir(tool))

  // 获取下载 URL
  let (url, root_path_depth) = @tools.get_download_url(os_info, tool, version)
  if url.is_blank() {
    @log.error("无法获取下载地址")
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
  let ignore_dirs = ["__MACOSX"]

  @log.debug("解压目录: \{extract_dir}, 目录深度: \{root_path_depth}")

  while find_sub_dir_count < root_path_depth {
    let entries = @fs.readdir(src_dir)
    if entries.is_empty() {
      raise fail(
        "无法从 \{extract_dir} 找到深度为 \{root_path_depth} 的目录",
      )
    }

    let dir_name = for entry in entries {
      let path = @fs_ext.join_path(src_dir, entry)
      // 跳过忽略的文件夹
      if ignore_dirs.contains(entry) {
        continue
      }
      // 跳过非文件夹
      if @fs.kind(path) is Directory {
        break entry
      }
    } nobreak {
      ""
    }
    if dir_name.is_blank() {
      raise fail("无法解析压缩包 \{src_dir} 的内容")
    }
    src_dir = @fs_ext.join_path(src_dir, dir_name)
    find_sub_dir_count += 1
  }
  // 移动到最终目录
  let final_dir = @tools.version_dir(tool, version)
  @log.debug(
    "目录 \{@utils.yellow(src_dir)} 移动到 \{@utils.yellow(final_dir)}",
  )

  @fs_ext.mv(src_dir, final_dir)

  // 清理临时文件
  @fs.rmdir(tmp_dir, recursive=true)

  // 安装之后的操作，比如增加可执行权限
  @tools.post_install(tool, final_dir)

  // 记录安装成功的工具
  add_installed(tool, version)

  @log.success("\{tool} \{version} 安装成功")
}

///|
/// 下载文件
pub async fn download_file(url : String, dest : String) -> Bool {
  @log.debug("正在下载: \{@utils.blue(url)}")
  @log.debug("保存到：\{dest}")
  @download.download_by_native_command(url, dest) catch {
    e => {
      @log.error("下载失败，原因：")
      @log.error(e)
      return false
    }
  }
  true
}

///|
/// 解压文件
pub async fn extract_file(file : String, dest : String) -> Bool {
  @log.debug("正在解压 \{file} 到 \{dest} ...")
  let (code, data) = match file {
    f if f.has_suffix(".tar.gz") =>
      @process.collect_output_merged("tar", ["-xzf", f, "-C", dest])
    f if f.has_suffix(".tar.xz") =>
      @process.collect_output_merged("tar", ["-xJf", f, "-C", dest])
    f if f.has_suffix(".zip") => {
      check_unzip_is_installed()
      @process.collect_output_merged("unzip", ["-q", "-o", f, "-d", dest])
    }
    _ => {
      @log.error("未知的压缩格式")
      return false
    }
  }
  @log.debug("解压结果: \{code}")
  match code {
    0 => true
    _ => {
      @log.error("解压失败，原因：")
      @log.error(data.text())
      false
    }
  }
}

///|
async fn check_unzip_is_installed() -> Unit {
  if !@command.command_exists("unzip") {
    raise fail("请先安装 unzip")
  }
}
