///|
const NODE_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
struct NodeJsInfo {
  version : String
  // date : String
  lts : Json
  files : Array[String]
} derive(@json.FromJson)

///|
async fn get_target_nodejs_version(os : @os.OsInfo, version : String) -> String {
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
    @utils.compare_version(b.version, a.version) catch {
      _ => 0
    }
  })
  // for item in nodeJsInfos {
  //   println("\{item.version} \{item.lts} \{item.date}")
  // }
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
      check_os_compatiable(
        os,
        nodeJsInfos[idx],
        error_msg_tpl="当前LTS版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
      )
    }
    "latest" =>
      // 按date排序，取第一个
      check_os_compatiable(os, nodeJsInfos[0])
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
          check_os_compatiable(os, nodeJsInfos[idx])
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
fn check_os_compatiable(
  os : @os.OsInfo,
  nodeJsInfo : NodeJsInfo,
  error_msg_tpl? : String = "版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
) -> String raise {
  // 判断当前操作系统、架构的文件是否支持
  let file_prefix = [
    match os.name {
      Windows => "win"
      MacOS => "osx"
      Linux => "linux"
      name => raise fail("不支持的操作系统：\{name}")
    },
    match os.arch {
      Aarch64 => "arm64"
      X86 => "x86"
      X86_64 => "x64"
      arch => raise fail("不支持的架构：\{arch}")
    },
  ].join("-")
  let { version, files, .. } = nodeJsInfo
  if files.all(v => !v.has_prefix(file_prefix)) {
    let variables = {
      "version": () => version,
      "os.name": () => os.name.to_string(),
      "os.arch": () => os.arch.to_string(),
    }
    let mut msg = error_msg_tpl
    for key, value in variables {
      msg = msg.replace_all(old="{\{key}}", new=@utils.yellow(value()))
    }
    raise fail(msg)
  }
  version
}

///|
fn get_nodejs_download_url(
  os_info : @os.OsInfo,
  version : String,
) -> String raise {
  let arch = if os_info.arch is Aarch64 { "arm64" } else { "x64" }
  let (os, ext) = match os_info.name {
    Windows => ("win", "zip")
    Linux => ("linux", "tar.gz")
    MacOS => ("darwin", "tar.gz")
    name => raise fail("不支持的操作系统：\{name}")
  }
  "\{NODE_RELEASE_URL}/\{version}/node-\{version}-\{os}-\{arch}.\{ext}"
}

///|
fn get_nodejs_exe_path(version : String) -> String {
  // TODO
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Node, version), "bin", "node", suffix]
  .filter(v => !v.is_blank())
  .join("/")
}
