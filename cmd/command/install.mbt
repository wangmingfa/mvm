///|
using @fs_ext {ensure_dir}

///|
/// 执行安装命令
/// skip_verify: 是否跳过 SHA256 校验（当无法获取校验值时，默认会警告并继续安装）
/// no_cache: 是否不使用缓存（跳过索引文件缓存和压缩包缓存，强制重新下载）
async fn run_install(
  tool : @tools.Tool,
  version : String?,
  skip_verify : Bool,
  no_cache : Bool,
) -> CommandResult {
  let result = CommandResult::success()
  // 设置全局 no_cache 模式（影响 read_cache_file_content 等缓存读写）
  @tools.set_no_cache_mode(no_cache)
  // 如果version为空，则默认为lts
  let version = if version is Some(version) { version } else { "" }
  let os_info = @os.get_os_info()
  let version = @tools.get_target_version(tool, version)

  // 检查是否已安装
  if @tools.is_installed(tool, version) {
    // @log 日志不捕获到 CommandResult
    @log.warn("\{tool}@\{version} 已安装")
    // 修复installed.json里面缺失已安装的版本的问题
    add_installed(tool, version)
    return result
  }

  @log.info("安装 \{@utils.yellow(tool)} \{@utils.yellow(version)}")

  // 确保目录存在
  ensure_dir(@tools.tool_dir(tool))

  // 获取下载信息（URL、headers、目录深度）
  let download_info = @tools.get_download_info(tool, version)
  if download_info.url.is_blank() {
    raise fail("无法获取下载地址")
  }

  // 应用全局配置（如镜像、代理）转换 URL
  let (_, config) = @tools.get_global_config()
  let arch_str = if os_info.arch is Aarch64 { "arm64" } else { "x64" }
  let os_str = match os_info.name {
    Windows => "win"
    Linux => "linux"
    MacOS => "darwin"
    _ => raise fail("不支持的操作系统")
  }
  let ctx = @tools.UrlReplaceContext::new(
    download_info.url,
    tool.to_string(),
    version,
    os_str,
    arch_str,
  )
  let url = @tools.apply_global_config(download_info.url, config, ctx)
  let headers = download_info.headers
  let root_path_depth = download_info.root_path_depth

  // 临时文件夹根目录
  let temp_dir_root = @tools.temp_dir()
  // 下载文件临时存放目录
  let tmp_dir = "\{@tools.temp_dir()}/tmp-\{tool}-\{version}"
  ensure_dir(tmp_dir)
  let ext = if url.has_suffix(".tar.gz") || url.has_suffix(".tgz") {
    "tar.gz"
  } else if url.has_suffix(".tar.xz") {
    "tar.xz"
  } else {
    "zip"
  }

  let archive_file_name = "\{tool}-\{version}.\{ext}"
  // 检查缓存目录是否已有该压缩包，如有则直接复用，无需重新下载
  // no_cache 模式下跳过压缩包缓存读取，强制重新下载
  let cached_archive_file = "\{temp_dir_root}/\{archive_file_name}"
  let archive_file = "\{tmp_dir}/\{archive_file_name}"
  let mut skip_download = false
  if !no_cache && @fs.exists(cached_archive_file) {
    @log.info(
      "发现已缓存的压缩包，直接复用: \{@utils.blue(cached_archive_file)}",
    )
    // 使用拷贝而非移动，防止用户 Ctrl+C 中断时缓存文件丢失
    @fs_ext.copy(cached_archive_file, archive_file)
    skip_download = true
  }

  if !skip_download {
    download_file(url, archive_file, headers~)
  }

  // SHA256 校验：skip_verify 为 true 时跳过整个校验逻辑（包括获取校验值）
  if skip_verify {
    @log.warn("已跳过 SHA256 校验（使用了 --skip-verify 参数）")
  } else {
    let expected_checksum = @tools.get_expected_checksum(os_info, tool, version)
    match expected_checksum {
      Some(expected) => {
        @log.info("正在校验 SHA256 ...")
        let verified = @checksum.verify_file_checksum(archive_file, expected)
        if !verified {
          @log.error("SHA256 校验失败！文件可能已损坏或被篡改")
          // 清除损坏的缓存文件和下载文件，防止续传拼接损坏数据
          if skip_download {
            @fs_ext.remove_if_exists(cached_archive_file)
          }
          @fs_ext.remove_if_exists(archive_file)
          // 自动重试：删除损坏文件后重新下载
          @log.info("正在重新下载（不使用缓存/续传）...")
          download_file(url, archive_file, headers~)
          let verified_retry = @checksum.verify_file_checksum(
            archive_file, expected,
          )
          if !verified_retry {
            @fs.rmdir(tmp_dir, recursive=true)
            raise fail(
              "重新下载后校验仍然失败，请检查网络或代理配置，或使用 --skip-verify 跳过校验",
            )
          }
        }
        @log.info("SHA256 校验通过")
      }
      None =>
        @log.warn("\{tool} 不支持 SHA256 校验，跳过校验继续安装")
    }
  }

  // 解压到临时目录
  let extract_dir = "\{tmp_dir}/extract-\{tool}-\{version}"
  ensure_dir(extract_dir)

  extract_file(archive_file, extract_dir)

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

  // 仅全新下载且非 no_cache 模式时才缓存压缩包
  // no_cache 模式下不缓存压缩包，复用缓存的情况下原文件已保留无需再缓存
  if !skip_download && !no_cache {
    let cached_archive_path = "\{temp_dir_root}/\{archive_file_name}"
    if @fs.exists(archive_file) {
      // 如果缓存目录已有同名文件（极少见），先移除再移动
      @fs_ext.remove_if_exists(cached_archive_path)
      @fs_ext.mv(archive_file, cached_archive_path)
      @log.debug("压缩包已缓存到: \{cached_archive_path}")
    }
  }

  // 清理临时文件
  @fs.rmdir(tmp_dir, recursive=true)

  // 安装之后的操作，比如增加可执行权限
  @tools.post_install(tool, final_dir)

  // 记录安装成功的工具
  add_installed(tool, version)

  // @log 日志不捕获到 CommandResult
  @log.success("\{tool} \{version} 安装成功")
  result
}

///|
/// 下载文件
/// headers: 下载请求需要携带的额外 headers
/// show_progress: 是否显示下载进度，默认为 true
async fn download_file(
  url : String,
  dest : String,
  headers? : Map[String, String] = {},
  show_progress? : Bool = true,
) -> Unit {
  @log.info("正在下载: \{@utils.blue(url)}")
  @log.info("保存到：\{dest}")
  // 优先使用 MoonBit HTTP 客户端下载，失败时回退到系统原生命令下载
  // 用户手动取消（Ctrl+C）不回退：用户意图是停止整个操作，而非切换下载方式
  @request.download(url, dest, dest_is_file=true, headers~, show_progress~) catch {
    e => {
      if @sys.is_cancelled(e) {
        raise e // 用户手动取消，不回退到原生命令
      }
      @log.warn(
        "HTTP 客户端下载失败，尝试使用系统原生命令下载...",
      )
      @request.download_by_native_command(url, dest, headers~, show_progress~)
    }
  }
}

///|
/// 解压文件
async fn extract_file(file : String, dest : String) -> Unit {
  @log.info("正在解压 \{file} 到 \{dest} ...")
  let (code, data) = match file {
    f if f.has_suffix(".tar.gz") || f.has_suffix(".tgz") =>
      @process.collect_output_merged("tar", ["-xzf", f, "-C", dest])
    f if f.has_suffix(".tar.xz") =>
      @process.collect_output_merged("tar", ["-xJf", f, "-C", dest])
    f if f.has_suffix(".zip") => unzip(file, dest)
    _ => raise fail("未知的压缩格式：\{file}")
  }
  @log.debug("解压结果: \{code}")
  match code {
    0 => ()
    _ => raise fail("解压失败，原因：\{data.text()}")
  }
}

///|
async fn check_unzip_is_installed() -> Unit {
  if !@mvm_cmd.command_exists("unzip") {
    raise fail("请先安装 unzip")
  }
}

///|
async fn unzip(zip_file_path : String, output_dir : String) -> (Int, &@io.Data) {
  let os = @os.get_os_name()
  match os {
    Linux | MacOS => {
      check_unzip_is_installed()
      @process.collect_output_merged("unzip", [
        "-q", "-o", zip_file_path, "-d", output_dir,
      ])
    }
    Windows =>
      @process.collect_output_merged("powershell", [
        "-Command",
        "Expand-Archive -Path \"\{zip_file_path}\" -DestinationPath \"\{output_dir}\" -Force",
      ])
    _ => raise fail("不支持的操作系统")
  }
}
