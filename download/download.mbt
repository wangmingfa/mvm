///|
using @fs_ext {get_parent_dir, ensure_dir}

///|
pub async fn download(
  url : String,
  dest : String,
  dest_is_file? : Bool = false,
) -> Unit {
  let exist_file_size = if dest_is_file && @fs.exists(dest) {
    let file = @fs.open(dest, mode=ReadOnly)
    defer file.close()
    file.size()
  } else {
    0
  }

  let (client, size, name, start) = get_client(url, range_start=exist_file_size)
  defer client.close()

  let dest_dir = if dest_is_file {
    guard get_parent_dir(dest) is Some(dir)
    dir
  } else {
    dest
  }
  ensure_dir(dest_dir)
  let is_append = start > 0
  println("文件大小：\{@utils.get_readable_file_size(size)}")
  if is_append {
    println(
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
  let progress_bar = @progress.ProgressBar::new(size)
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
  @progress.clear_progress()
  println(
    "\n文件已保存：\{file_path} 耗时：\{@utils.get_readable_time(progress_bar.duration())}",
  )
}

///|
async fn get_client(
  url : String,
  range_start? : Int64 = 0,
) -> (@http.Client, Int64, String, Int64) {
  let (res, client) = @http.get_stream(url, headers={
    "User-Agent": "curl/8.7.1",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Range": "bytes=\{range_start}-",
  })
  match res.code {
    301 | 302 => {
      client.close()
      let location = @utils.get_from_map_ignore_case(res.headers, "Location")
      guard location is Some(location) else {
        raise fail("重定向失败: 未找到 Location 头")
      }
      println("重定向到：\{location}")
      get_client(location, range_start~)
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
    _ => raise fail("下载失败，原因：\{res.code} \{res.reason}")
  }
}

///|
async test "download" {
  let start = @async.now()
  guard @env.current_dir() is Some(dir)
  let output_path = "\{dir}/.temp/游戏直播大师课.zip"
  // "https://cdn.gh-proxy.org/https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip",
  // let url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip"
  let url = "https://szpdmtest.vivo.xyz/filemanager/api/attachment/download?code=E9ABC642472443F18909366E6FB22B77"
  download(url, output_path, dest_is_file=true)
  let end = @async.now()
  let time = end - start
  println("耗时：\{@utils.get_readable_time(time)}")
}

///|
pub async fn download_by_native_command(url : String, dest : String) -> Unit {
  guard @command.get_best_downloader() is Some(downloader) else {
    raise fail("没有找到合适的下载器，请安装curl或者wget")
  }
  let args = match downloader {
    "curl" | "curl.exe" => {
      // curl 命令
      let args = [
        "-L", // 跟随重定向
         "-C", "-", // 断点续传
         "--max-time", "300", // 5分钟超时
         "--retry", "3", // 重试3次
         "--retry-delay", "5", // 重试间隔5秒
         "--show-error", // 显示错误信息
         "-o", dest, // 输出文件
         url,
      ]

      args
    }
    "wget" => {
      // wget 命令
      let args = [
        "-c", //断点续传
         "--tries=3", // 重试3次
         "--timeout=300", // 5分钟超时
         "--waitretry=5", // 重试间隔5秒
         "-O", dest, // 输出文件
         url,
      ]

      args
    }
    "powershell" => {
      // PowerShell 命令 (Windows 备用方案)
      let ps_script = "Invoke-WebRequest -Uri '" +
        url +
        "' -OutFile '" +
        dest +
        "' -UserAgent 'Mozilla/5.0' -MaximumRedirection 5 -TimeoutSec 300"

      let args = ["-Command", ps_script]

      args
    }
    _ => raise fail("不支持的下载方式")
  }
  match @process.run(downloader, args) {
    0 => ()
    _ => raise fail("下载失败")
  }
}

///|
async test "download_by_native_command" {
  let url = "https://mirrors.aliyun.com/nodejs-release/v21.7.3/node-v21.7.3-linux-x64.tar.gz"
  let name = @fs_ext.get_path_name(url)
  let dest_dir = ".temp/\{@async.now()}"
  ensure_dir(dest_dir)
  let dest = @fs_ext.join_path(dest_dir, name)
  download_by_native_command(url, dest)
}
