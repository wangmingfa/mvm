///|
using @fs_ext {get_parent_dir, ensure_dir}

///|
async fn get_file_size_from_url(url : String) -> Int64? {
  let os = @os.get_os_name()
  match os {
    Windows => get_file_size_with_curl_exe(url)
    _ => get_file_size_with_curl(url)
  }
}

///|
/// 从 HTTP 响应头文本中解析 Content-Length 值
fn parse_content_length_from_headers(header_text : String) -> Int64? {
  let lines = header_text.split("\n").collect()
  for line in lines {
    let line = line.trim()
    if line.has_prefix("Content-Length:") {
      let value = line["Content-Length:".length():].trim()
      let size = @string.parse_int64(value) catch { _ => return None }
      return Some(size)
    }
  }
  None
}

///|
/// 通用函数：使用指定命令获取文件大小
/// 通过运行 curl/curl.exe -sI 命令并解析 Content-Length 头来获取文件大小
async fn get_file_size_by_command(cmd_name : String, url : String) -> Int64? {
  let (code, output) = @process.collect_stdout(cmd_name, ["-sI", url]) catch {
    _ => return None
  }
  if code == 0 {
    return parse_content_length_from_headers(output.text())
  }
  None
}

///|
async fn get_file_size_with_curl_exe(url : String) -> Int64? {
  // 优先使用 curl.exe 获取文件大小，因为powershell的Invoke-WebRequest会有蓝色背景闪烁，体验不好
  let size = get_file_size_by_command("curl.exe", url)
  if size is Some(_) {
    return size
  }
  // curl.exe 失败时 fallback 到 PowerShell
  get_file_size_with_powershell(url)
}

///|
async fn get_file_size_with_curl(url : String) -> Int64? {
  get_file_size_by_command("curl", url)
}

///|
async fn get_file_size_with_powershell(url : String) -> Int64? {
  let ps_script =
    $| try { 
    $|  $response = Invoke-WebRequest -Uri '\{url}' -Method Head -UserAgent 'curl/8.7.1' -UseBasicParsing -ErrorAction Stop; 
    $|  $response.Headers['Content-Length'] 
    $|} catch { 
    $|  '0' 
    $|}

  let (code, output) = @process.collect_stdout("powershell", [
    "-Command", ps_script,
  ]) catch {
    _ => return None
  }
  if code == 0 {
    let stdout = output.text().trim()
    if stdout != "0" {
      let size = @string.parse_int64(stdout) catch { _ => return None }
      return Some(size)
    }
  }
  None
}

///|
priv suberror DownloadError {
  FileAlreadyComplete
}

///|
/// 下载文件（使用 MoonBit HTTP 客户端）
/// headers: 下载请求需要携带的额外 headers（会与默认 headers 合并）
/// show_progress: 是否显示下载进度条，默认为 true
/// 网络连接失败/超时类错误最多重试 3 次，间隔 1s → 3s → 5s；HTTP 4xx/5xx 不重试
pub async fn download(
  url : String,
  dest : String,
  dest_is_file? : Bool = false,
  headers? : Map[String, String] = {},
  show_progress? : Bool = true,
) -> Unit {
  let max_retries = 3
  let retry_intervals : Array[Int] = [1000, 3000, 5000]
  for attempt in 0..<4 {
    try {
      // 每次重试重新检查已有文件大小，以支持断点续传
      let exist_file_size = if dest_is_file && @fs.exists(dest) {
        let file = @fs.open(dest, mode=ReadOnly)
        defer file.close()
        file.size()
      } else {
        0
      }

      let (client, size, name, start) = get_client(
        url,
        range_start=exist_file_size,
        dest~,
        dest_is_file~,
        headers~,
      ) catch {
        e => {
          if e is DownloadError::FileAlreadyComplete {
            @log.info("文件已完整下载，跳过")
            return
          }
          raise e
        }
      }
      defer client.close()

      let dest_dir = if dest_is_file {
        guard get_parent_dir(dest) is Some(dir) else {
          raise fail("无法获取到 \{dest} 的父目录")
        }
        dir
      } else {
        dest
      }
      ensure_dir(dest_dir)
      let is_append = start > 0
      @log.debug("文件大小：\{@utils.get_readable_file_size(size)}")
      if is_append {
        @log.debug(
          "文件 \{dest} 支持断点续传，已下载大小：\{@utils.get_readable_file_size(start)}",
        )
      }
      let file_path = if dest_is_file { dest } else { "\{dest_dir}/\{name}" }
      let file = @fs.open(
        file_path,
        mode=@fs.Mode::WriteOnly,
        append=is_append,
        create_mode=if is_append { OpenOrCreate } else { CreateOrTruncate },
        sync=Data,
      )
      defer file.close()
      if show_progress {
        let progress_bar = @progress.ProgressBar(size)
        @async.any([
          () => file.write_reader(client),
          () => {
            while true {
              let current_size = file.size()
              progress_bar.set_completed(current_size)
              @async.sleep(1000)
            }
          },
        ])
        progress_bar.set_complete()
        progress_bar.clear()
        println("")
        @log.info(
          "文件已保存：\{file_path} 耗时：\{@utils.get_readable_time(progress_bar.duration())}",
        )
      } else {
        file.write_reader(client)
        @log.info("文件已保存：\{file_path}")
      }
      return // 下载成功，退出重试循环
    } catch {
      e => {
        if e is DownloadError::FileAlreadyComplete {
          return
        }
        if @sys.is_cancelled(e) {
          raise e // 用户手动取消
        }
        if attempt < max_retries {
          @log.warn("下载失败，第 \{attempt + 1} 次重试...")
          @async.sleep(retry_intervals[attempt])
        } else {
          raise e // 重试次数已耗尽，抛出错误
        }
      }
    }
  }
}

///|
async fn get_client(
  url : String,
  range_start? : Int64 = 0,
  dest? : String = "",
  dest_is_file? : Bool = false,
  headers? : Map[String, String] = {},
) -> (@http.Client, Int64, String, Int64) {
  // 合并默认 headers 和用户提供的 headers
  // 用户提供的 headers 会覆盖默认值
  let headers = merge_detault_headers(headers~)
  // 设置range以支持断点续传
  headers.set("Range", "bytes=\{range_start}-")
  let (res, client) = @http.get_stream(url, headers~)
  match res.code {
    301 | 302 => {
      client.close()
      let location = @utils.get_from_map_ignore_case(res.headers, "Location")
      guard location is Some(location) else {
        raise fail("重定向失败: 未找到 Location 头")
      }
      @log.debug("重定向到：\{location}")
      get_client(location, range_start~, dest~, dest_is_file~, headers~)
    }
    416 => {
      client.close()
      if dest_is_file && range_start > 0 && dest != "" {
        let exist_file_size = if @fs.exists(dest) {
          let file = @fs.open(dest, mode=ReadOnly)
          defer file.close()
          file.size()
        } else {
          0
        }
        let remote_size = get_file_size_from_url(url)
        match remote_size {
          Some(remote_size) if exist_file_size == remote_size =>
            raise DownloadError::FileAlreadyComplete
          _ => ()
        }
      }
      @log.debug("服务器不支持断点续传（416），将重新下载...")
      get_client(url, range_start=0, headers~)
    }
    200..<300 as code => {
      let size = if @utils.get_from_map_ignore_case(
          res.headers,
          "Content-Length",
        )
        is Some(length) {
        @string.parse_int64(length) catch {
          _ => 0
        }
      } else {
        0
      }
      let name = get_file_name(url, res.headers)
      let is_append = code == 206 && range_start > 0
      (
        client,
        size + (if is_append { range_start } else { 0 }),
        name,
        if is_append {
          range_start
        } else {
          0
        },
      )
    }
    _ => raise fail("[HTTP]\{res.code} \{res.reason} (\{url})")
  }
}

///|
test "parse_content_length_from_headers" {
  // 正常格式
  let headers = "HTTP/1.1 200 OK\nContent-Type: application/octet-stream\nContent-Length: 1234567\nAccept-Ranges: bytes\n"
  guard parse_content_length_from_headers(headers) is Some(1234567L) else {
    fail("should parse Content-Length correctly")
  }
  // Content-Length 前后有空格
  let headers2 = "Content-Length:  999  \n"
  guard parse_content_length_from_headers(headers2) is Some(999L) else {
    fail("should parse Content-Length with spaces")
  }
  // 没有 Content-Length 头
  let headers3 = "HTTP/1.1 200 OK\nContent-Type: text/html\n"
  guard parse_content_length_from_headers(headers3) is None else {
    fail("should return None when no Content-Length")
  }
  // 无效的 Content-Length 值
  let headers4 = "Content-Length: abc\n"
  guard parse_content_length_from_headers(headers4) is None else {
    fail("should return None for invalid Content-Length")
  }
}

///|
async test "download" {
  let start = @async.now()
  guard @env.current_dir() is Some(dir)
  // 使用阿里云镜像上的小文件（~810KB），测试速度快且能验证进度条
  let url = "https://mirrors.aliyun.com/macports/distfiles/bzip2/bzip2-1.0.8.tar.gz"
  let output_path = "\{dir}/.temp/bzip2-1.0.8.tar.gz"
  download(url, output_path, dest_is_file=true)
  let end = @async.now()
  let time = end - start
  println("耗时：\{@utils.get_readable_time(time)}")
}

///|
/// 使用系统原生命令下载文件（curl/wget/powershell）
/// headers: 下载请求需要携带的额外 headers
/// show_progress: 是否显示下载进度，默认为 true
pub async fn download_by_native_command(
  url : String,
  dest : String,
  headers? : Map[String, String] = {},
  show_progress? : Bool = true,
) -> Unit {
  guard @command.get_best_downloader() is Some(downloader) else {
    // 没有找到合适的下载器
    raise fail(@i18n.t("error.no_downloader"))
  }
  // 构建 curl 格式的 header 参数（每个 header 生成 "-H" 和 "key: value" 两个参数）
  let curl_header_args : Array[String] = []
  for k, v in headers {
    curl_header_args.push("-H")
    curl_header_args.push("\{k}: \{v}")
  }
  // 构建 wget 格式的 header 参数（每个 header 生成一个 "--header=key: value" 参数）
  let wget_header_args : Array[String] = []
  for k, v in headers {
    wget_header_args.push("--header=\{k}: \{v}")
  }
  // 根据 show_progress 构建 curl/wget 的进度相关参数
  let curl_silent_args : Array[String] = if show_progress { [] } else { ["-s"] }
  let wget_progress_args : Array[String] = if show_progress {
    ["--show-progress"]
  } else {
    []
  }
  let args : Array[String] = match downloader {
    "curl" | "curl.exe" => {
      // curl 命令
      if show_progress {
        @log.add_log_lines(lines=2)
      }
      [
        "-L", // 跟随重定向
         "-C", "-", // 断点续传
         "--max-time", "300", // 5分钟超时
         "--retry", "3", // 重试3次
         "--retry-delay", "5", // 重试间隔5秒
         "--show-error", // 显示错误信息
         ..curl_silent_args, // 不显示进度时添加静默模式
         ..curl_header_args, // 额外的 headers
         "-o", dest, // 输出文件
         url,
      ]
    }
    "wget" => {
      // wget 命令
      if show_progress {
        @log.add_log_lines(lines=1)
      }
      [
        "-c", // 断点续传
         ..wget_progress_args, // 进度条（仅显示进度时启用）
         "-q", // quiet 关闭大部分日志
         "--tries=3", // 重试3次
         "--timeout=300", // 5分钟超时
         "--waitretry=5", // 重试间隔5秒
         ..wget_header_args, // 额外的 headers
         "-O", dest, // 输出文件
         url,
      ]
    }
    "powershell" => {
      // PowerShell 命令 (Windows 备用方案)
      // 构建 headers 字典字符串
      let headers_str = if headers.is_empty() {
        ""
      } else {
        let pairs : Array[String] = []
        for k, v in headers {
          pairs.push("'\{k}'='\{v}'")
        }
        let pairs_str = pairs.join("; ")
        " -Headers @{ " + pairs_str + " }"
      }
      let ps_script = "Invoke-WebRequest -Uri '" +
        url +
        "' -OutFile '" +
        dest +
        "' -UserAgent 'Mozilla/5.0' -MaximumRedirection 5 -TimeoutSec 300" +
        headers_str

      ["-Command", ps_script]
    }
    _ => raise fail("不支持的下载方式")
  }
  let args_str = args.join(" ")
  let cmd = "\{downloader} \{args_str}"
  @log.debug("下载命令: \{cmd}")

  let os = @os.get_os_name()
  let (downloader, args) = match os {
    Windows =>
      // powershell 命令需要包装一层
      ("powershell", ["-Command", cmd])
    _ => (downloader, args)
  }

  match @process.run(downloader, args) {
    0 => ()
    _ => {
      @log.warn("使用 \{downloader} 下载失败")
      raise fail("下载失败")
    }
  }
}

///|
async test "download_by_native_command" {
  // 使用阿里云镜像上的小文件（~2KB SHASUMS256.txt），测试速度快
  let url = "https://mirrors.aliyun.com/nodejs-release/v22.14.0/SHASUMS256.txt"
  let name = @fs_ext.get_path_name(url)
  let dest_dir = ".temp/\{@async.now()}"
  ensure_dir(dest_dir)
  let dest = @fs_ext.join_path(dest_dir, name)
  download_by_native_command(url, dest)
}