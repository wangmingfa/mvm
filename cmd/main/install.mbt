///|
/// 确保目录存在
async fn ensure_dir(dir : String) -> Unit {
  if @fs.exists(dir) {
    return
  }
  @fs.mkdir(dir.to_string_view(), permission=0o750, recursive=true) catch {
    e => raise fail("创建文件夹 \{dir} 失败，原因：\{e}")
  }
}

///|
const NODE_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
struct NodeJsInfo {
  version : String
  date : String
  lts : Json
} derive(@json.FromJson)

///|
async fn get_proper_nodejs_version(version : String) -> String {
  // version支持这些格式：
  // lts：下载lts版本
  // latest：下载最新版本
  // 20：指定主版本，下载20版本下的最新版本
  // 20.1：指定主版本和次版本，下载20.1版本下的最新版本
  // 24.1.0：指定完整的版本

  let version_count = lexmatch version {
    // x.y.z
    "v?[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" => 3
    // x.y
    "v?[[:digit:]]+\.[[:digit:]]+" => 2
    // x
    "v?[[:digit:]]+" => 1
    _ =>
      match version {
        "lts" | "latest" => 0
        _ => raise fail("无效的版本：\{version}")
      }
  }

  // 从https://nodejs.org/dist/index.json中解析，将version转换为为具体的x.y.z版本号
  let (res, data) = @http.get("https://nodejs.org/dist/index.json")
  guard res.code is (200..<300) else {
    raise fail("无法获取到Node.js版本信息：\{res.reason}")
  }
  let json = data.json()
  guard json is Array(arr) else {
    raise fail("Node.js版本信息格式不对")
  }
  // for index, item in arr {
  //   println("\{index}: \{item}")
  //   let _ : NodeJsInfo = @json.from_json(item)
  // }
  let nodeJsInfos : Array[NodeJsInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e => raise fail("解析Node.js版本信息失败，原因：\{e}")
    }
  })
  guard nodeJsInfos.length() > 0 else {
    raise fail("Node.js版本信息格式为空")
  }
  // 按date倒序排序
  nodeJsInfos.sort_by((a, b) => {
    if a.date >= b.date {
      return 0
    }
    return 1
  })
  match version {
    "lts" => {
      guard nodeJsInfos.search_by(fn(v) {
          if v.lts is String(_) {
            return true
          }
          false
        })
        is Some(idx) else {
        raise fail("找不到lts版本")
      }
      nodeJsInfos[idx].version
    }
    "latest" =>
      // 按date排序，取第一个
      nodeJsInfos[0].version
    _ =>
      match version_count {
        1..=3 => {
          guard nodeJsInfos.search_by(v => {
              let version = if version.has_prefix("v") {
                version
              } else {
                "v\{version}"
              }
              if version_count == 3 {
                v.version == version
              } else {
                v.version.has_prefix(version + ".")
              }
            })
            is Some(idx) else {
            raise fail("找不到版本：\{version}")
          }
          nodeJsInfos[idx].version
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
async fn get_target_version(tool : @lib.Tool, version : String) -> String {
  match tool {
    Npm => ...
    Node => get_proper_nodejs_version(version)
    Zig => ...
  }
}

///|
fn get_nodejs_download_url(os_info : @lib.OsInfo, version : String) -> String {
  let arch = if os_info.arch is Arm64 { "arm64" } else { "x64" }
  let (os, ext) = match os_info.name {
    Windows => ("win", "zip")
    Linux => ("linux", "tar.gz")
    MacOS => ("darwin", "tar.gz")
  }
  "\{NODE_RELEASE_URL}/\{version}/node-\{version}-\{os}-\{arch}.\{ext}"
}

///|
/// 获取下载 URL
fn get_download_url(
  os_info : @lib.OsInfo,
  tool : @lib.Tool,
  version : String,
) -> String {
  match tool {
    @lib.Node => get_nodejs_download_url(os_info, version)
    // @lib.Bun =>
    //   "https://github.com/oven-sh/bun/releases/download/bun-v\{version}/bun-\{os}-\{arch}.zip"
    @lib.Zig => {
      let arch = if os_info.arch is Arm64 { "aarch64" } else { "x86_64" }
      let (os, ext) = match os_info.name {
        Windows => ("windows", "zip")
        Linux => ("linux", "tar.gz")
        MacOS => ("darwin", "tar.gz")
      }
      "https://ziglang.org/download/\{version}/zig-\{os}-\{arch}-\{version}.\{ext}"
    }
    @lib.Npm =>
      // npm 随 node 安装，不单独下载
      ""
  }
}

///|
/// 下载文件
async fn download_file(
  os_info : @lib.OsInfo,
  url : String,
  dest : String,
) -> Bool {
  println("正在下载: \{url}")
  println("保存到：\{dest}")
  let (code, data) = match os_info.name {
    @lib.MacOS | @lib.Linux =>
      @process.collect_output_merged("curl", [
        "-L", // 跟随重定向
         "-o", dest, // 输出文件
         "--progress-bar", // 显示进度条
         url,
      ])
    @lib.Windows =>
      @process.collect_output_merged("powershell", [
        "-Command",
        "Invoke-WebRequest -Uri '\{url}' -OutFile '\{dest}' -UseBasicParsing",
      ])
  }
  match code {
    0 => {
      println("下载完成")
      true
    }
    _ => {
      println("下载失败，原因：")
      println(data.text())
      false
    }
  }
}

///|
/// 解压文件
async fn extract_file(file : String, dest : String) -> Bool {
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

///|
/// 执行安装命令
pub async fn run_install(tool : @lib.Tool, version : @lib.Version) -> Unit {
  let version = get_target_version(tool, version.value())

  // 检查是否已安装
  if @lib.is_installed(tool, version) {
    println("\{tool}@\{version} 已安装")
    return
  }

  // npm 随 node 安装
  if tool is @lib.Npm {
    println("npm 会随 node 自动安装，请先安装 node")
    return
  }

  // 确保目录存在
  ensure_dir(@lib.tool_dir(tool))

  let os_info = @lib.get_os_info()
  // 获取下载 URL
  let url = get_download_url(os_info, tool, version)
  if url.is_blank() {
    println("无法获取下载地址")
    return
  }

  // 下载文件
  let tmp_dir = "\{@lib.mvm_home()}/tmp"
  ensure_dir(tmp_dir)
  let ext = if url.has_suffix(".tar.gz") {
    "tar.gz"
  } else if url.has_suffix(".tar.xz") {
    "tar.xz"
  } else {
    "zip"
  }
  let archive_file = "\{tmp_dir}/\{tool}-\{version}.\{ext}"

  if !download_file(os_info, url, archive_file) {
    return
  }

  // 解压到临时目录
  let extract_dir = "\{tmp_dir}/extract-\{tool}-\{version}"
  ensure_dir(extract_dir)

  if !extract_file(archive_file, extract_dir) {
    return
  }

  // 移动到最终目录
  let final_dir = @lib.version_dir(tool, version)
  let _ = @process.run("mv", [extract_dir, final_dir])

  // 清理临时文件
  let _ = @process.run("rm", ["-rf", tmp_dir])

  println("\{tool}@\{version} 安装成功")
}
