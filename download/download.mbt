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
