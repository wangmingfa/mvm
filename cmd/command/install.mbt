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
    // {tool}@{version} 已安装
    @log.warn(
      @i18n.t("install.already_installed", args={
        "tool": tool.to_string(),
        "version": version,
      }),
    )
    // 修复installed.json里面缺失已安装的版本的问题
    add_installed(tool, version)
    return result
  }

  // 安装 {tool} {version}
  @log.info(
    @i18n.t("install.installing", args={
      "tool": @utils.yellow(tool.to_string()),
      "version": @utils.yellow(version),
    }),
  )

  // 确保目录存在
  ensure_dir(@tools.tool_dir(tool))

  // 获取下载信息（URL、headers、目录深度）
  let download_info = @tools.get_download_info(tool, version)
  if download_info.url.is_blank() {
    // 无法获取下载地址
    raise fail(@i18n.t("install.no_download_url"))
  }

  // 应用全局配置（如镜像、代理）转换 URL
  let (_, config) = @tools.get_global_config()
  let arch_str = if os_info.arch is Aarch64 { "arm64" } else { "x64" }
  let os_str = match os_info.name {
    Windows => "win"
    Linux => "linux"
    MacOS => "darwin"
    // 不支持的操作系统
    _ => raise fail(@i18n.t("install.unsupported_os"))
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
  let tmp_dir = @fs_ext.join_path(@tools.temp_dir(), "tmp-\{tool}-\{version}")
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
  let cached_archive_file = @fs_ext.join_path(temp_dir_root, archive_file_name)
  let archive_file = @fs_ext.join_path(tmp_dir, archive_file_name)
  let mut skip_download = false
  if !no_cache && @fs.exists(cached_archive_file) {
    // 必须是文件
    match @fs.kind(cached_archive_file) {
      Regular => {
        // 发现已缓存的压缩包，直接复用
        @log.info(
          @i18n.t("install.cached_archive", args={
            "path": @utils.blue(cached_archive_file),
          }),
        )
        // 使用拷贝而非移动，防止用户 Ctrl+C 中断时缓存文件丢失
        @fs_ext.copy(cached_archive_file, archive_file)
        skip_download = true
      }
      _ =>
        // 处理一些边界场景
        @fs_ext.remove_if_exists(cached_archive_file)
    }
  }

  if skip_download {
    // 跳过下载
    @log.debug(@i18n.t("install.skip_download"))
  } else {
    // 开始下载
    @log.debug(@i18n.t("install.start_download"))
    download_file(url, archive_file, headers~)
  }

  // SHA256 校验：skip_verify 为 true 时跳过整个校验逻辑（包括获取校验值）
  if skip_verify {
    // 已跳过 SHA256 校验（使用了 --skip-verify 参数）
    @log.warn(@i18n.t("install.skip_verify"))
  } else {
    let expected_checksum = @tools.get_expected_checksum(os_info, tool, version)
    match expected_checksum {
      Some(expected) => {
        // 正在校验 SHA256
        @log.info(@i18n.t("install.verifying"))
        let verified = @checksum.verify_file_checksum(archive_file, expected)
        if !verified {
          // SHA256 校验失败！文件可能已损坏或被篡改
          @log.error(@i18n.t("install.verify_failed"))
          // 清除损坏的缓存文件和下载文件，防止续传拼接损坏数据
          if skip_download {
            @fs_ext.remove_if_exists(cached_archive_file)
          }
          @fs_ext.remove_if_exists(archive_file)
          // 自动重试：删除损坏文件后重新下载
          // 正在重新下载（不使用缓存/续传）
          @log.info(@i18n.t("install.retry_download"))
          download_file(url, archive_file, headers~)
          let verified_retry = @checksum.verify_file_checksum(
            archive_file, expected,
          )
          if !verified_retry {
            @fs.rmdir(tmp_dir, recursive=true)
            // 重新下载后校验仍然失败，请检查网络或代理配置，或使用 --skip-verify 跳过校验
            raise fail(@i18n.t("install.retry_failed"))
          }
        }
        // SHA256 校验通过
        @log.info(@i18n.t("install.verify_passed"))
      }
      None =>
        // {tool} 不支持 SHA256 校验，跳过校验继续安装
        @log.warn(
          @i18n.t("install.no_checksum", args={ "tool": tool.to_string() }),
        )
    }
  }

  // 解压到临时目录
  let extract_dir = @fs_ext.join_path(tmp_dir, "extract-\{tool}-\{version}")
  ensure_dir(extract_dir)

  extract_file(archive_file, extract_dir)

  let mut src_dir = extract_dir
  let mut find_sub_dir_count : UInt = 0
  let ignore_dirs = ["__MACOSX"]

  // 解压目录和目录深度
  @log.debug(
    @i18n.t("install.debug_extract_info", args={
      "extract_dir": extract_dir,
      "depth": root_path_depth.to_string(),
    }),
  )

  while find_sub_dir_count < root_path_depth {
    let entries = @fs.readdir(src_dir)
    if entries.is_empty() {
      // 无法从目录找到指定深度的子目录
      raise fail(
        @i18n.t("install.cannot_find_dir_depth", args={
          "extract_dir": extract_dir,
          "depth": root_path_depth.to_string(),
        }),
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
      // 无法解析压缩包的内容
      raise fail(
        @i18n.t("install.cannot_parse_archive", args={ "path": src_dir }),
      )
    }
    src_dir = @fs_ext.join_path(src_dir, dir_name)
    find_sub_dir_count += 1
  }
  // 移动到最终目录
  let final_dir = @tools.version_dir(tool, version)
  // 目录移动
  @log.debug(
    @i18n.t("install.debug_move_info", args={
      "src": @utils.yellow(src_dir),
      "dest": @utils.yellow(final_dir),
    }),
  )

  @fs_ext.mv(src_dir, final_dir, remove_dest_if_exists=true)

  // 仅全新下载且非 no_cache 模式时才缓存压缩包
  // no_cache 模式下不缓存压缩包，复用缓存的情况下原文件已保留无需再缓存
  if !skip_download && !no_cache {
    let cached_archive_path = @fs_ext.join_path(
      temp_dir_root, archive_file_name,
    )
    if @fs.exists(archive_file) {
      // 缓存压缩包
      @log.debug(
        @i18n.t("install.debug_cache_move", args={
          "src": archive_file,
          "dest": cached_archive_path,
        }),
      )
      // 如果缓存目录已有同名文件（极少见），先移除再移动
      @fs_ext.remove_if_exists(cached_archive_path)
      @fs_ext.mv(archive_file, cached_archive_path)
      // 压缩包已缓存到
      @log.debug(
        @i18n.t("install.debug_cached_to", args={ "path": cached_archive_path }),
      )
    }
  }

  // 清理临时文件
  @fs.rmdir(tmp_dir, recursive=true)

  // 安装之后的操作，比如增加可执行权限
  @tools.post_install(tool, final_dir)

  // 记录安装成功的工具
  add_installed(tool, version)

  // {tool} {version} 安装成功
  @log.success(
    @i18n.t("install.install_success", args={
      "tool": tool.to_string(),
      "version": version,
    }),
  )
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
  // 正在下载
  @log.info(@i18n.t("install.downloading", args={ "url": @utils.blue(url) }))
  // 保存到
  @log.info(@i18n.t("install.saving_to", args={ "dest": dest }))
  // 优先使用系统原生命令下载（速度更快），失败时回退到 MoonBit HTTP 客户端
  // 用户手动取消（Ctrl+C）不回退：用户意图是停止整个操作，而非切换下载方式
  @request.download_by_native_command(url, dest, headers~, show_progress~) catch {
    e => {
      if @sys.is_cancelled(e) {
        raise e // 用户手动取消，不回退到 HTTP 客户端
      }
      // 原生命令下载失败，回退到 MoonBit HTTP 客户端下载
      @log.warn(@i18n.t("install.fallback_http"))
      @log.warn(e.to_string())
      @request.download(url, dest, dest_is_file=true, headers~, show_progress~)
    }
  }
}

///|
/// 解压文件
async fn extract_file(file : String, dest : String) -> Unit {
  // 正在解压
  @log.info(@i18n.t("install.extracting", args={ "file": file, "dest": dest }))
  if file.has_suffix(".zip") {
    extract_zip(file, dest)
    return ()
  }
  let (code, data) = match file {
    f if f.has_suffix(".tar.gz") || f.has_suffix(".tgz") =>
      @mvm_cmd.collect_output_merged("tar", ["-xzf", f, "-C", dest])
    f if f.has_suffix(".tar.xz") =>
      @mvm_cmd.collect_output_merged("tar", ["-xJf", f, "-C", dest])
    // 未知的压缩格式
    _ => raise fail(@i18n.t("install.unknown_format", args={ "file": file }))
  }
  // 解压结果码
  @log.debug(
    @i18n.t("install.debug_extract_result", args={ "code": code.to_string() }),
  )
  match code {
    0 => ()
    // 解压失败
    _ =>
      raise fail(
        @i18n.t("install.extract_failed", args={ "reason": data.text() }),
      )
  }
}

///|
/// 解压 zip 文件
/// 优先使用系统 unzip 命令（速度更快），失败时回退到 zipx 库
async fn extract_zip(file : String, dest : String) -> Unit {
  let unzip_available = @mvm_cmd.collect_output_merged("unzip", ["-v"])
  if unzip_available.0 == 0 {
    let (code, data) = @mvm_cmd.collect_output_merged(
      "unzip",
      ["-o", file, "-d", dest],
    )
    if code == 0 {
      return ()
    }
    @log.warn(@i18n.t("install.fallback_zipx"))
    @log.warn(data.text())
  }
  try {
    let _ = @zipx.unzip_file_path(file, output_dir=dest)
  } catch {
    e => {
      let os = @os.get_os_name()
      let hint = match os {
        MacOS => "brew install unzip"
        Linux => "apt-get install unzip (Debian/Ubuntu) 或 yum install unzip (CentOS/RHEL)"
        Windows => "winget install unzip"
        _ => @i18n.t("install.install_unzip_unknown")
      }
      raise fail(
        @i18n.t("install.extract_failed_hint", args={
          "reason": e.to_string(),
          "hint": hint,
        }),
      )
    }
  }
}
