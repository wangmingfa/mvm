///|
const NODE_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
const NODE_INDEX_URL = "https://nodejs.org/dist/index.json"

///|
const NODE_INDEX_CACHE_FILE = "nodejs_index.json"

///|
struct Node {}

///|
test "Node" {
  // 去除 Warning (struct_never_constructed) 警告
  let _ = Node::{  }
}

///|
struct NodeJsInfo {
  version : String
  // date : String
  lts : Json
  files : Array[String]
} derive(@json.FromJson)

///|
pub async fn Node::get_target_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
) -> String {
  if version_count == 3 {
    // 从缓存中获取
    let cache_file_content = read_cache_file_content(NODE_INDEX_CACHE_FILE)
    if cache_file_content is Some(content) {
      let json = @json.parse(content)
      let target_version = Node::_get_proper_version(
        os, version, version_count, json,
      ) catch {
        _ => ""
      }
      if !target_version.is_blank() {
        return target_version
      }
    }
  }
  // 从https://nodejs.org/dist/index.json中解析，将version转换为为具体的x.y.z版本号
  let (res, data) = @http.get(NODE_INDEX_URL)
  guard res.code is (200..<300) else {
    raise fail("无法获取到Node.js版本信息：\{res.reason}")
  }
  let json = data.json()
  write_cache_file_content(NODE_INDEX_CACHE_FILE, json.stringify(indent=2))
  Node::_get_proper_version(os, version, version_count, json)
}

///|
fn Node::_get_proper_version(
  os : @os.OsInfo,
  version : String,
  version_count : Int,
  json : Json,
) -> String raise {
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
      Node::_check_os_compatiable(
        os,
        nodeJsInfos[idx],
        error_msg_tpl="当前LTS版本 {version} 不支持 {os.name} 操作系统下的 {os.arch} 架构",
      )
    }
    "latest" =>
      // 按date排序，取第一个
      Node::_check_os_compatiable(os, nodeJsInfos[0])
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
          Node::_check_os_compatiable(os, nodeJsInfos[idx])
        }
        _ => raise fail("无效的版本号：\{version}")
      }
  }
}

///|
fn Node::_check_os_compatiable(
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
pub fn Node::get_download_url(
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
pub fn Node::get_exe_path(version : String) -> String {
  // TODO
  let os = @os.get_os_name()
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Node, version), "bin", "node", suffix]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
pub async fn Node::get_node_builtin_tool_path_and_version(
  tool : Tool,
  node_exe_path : String,
) -> (String, String)? {
  // 处理node内置工具

  guard @fs_ext.get_parent_dir(node_exe_path) is Some(node_bin_dir) else {
    @log.error("无法获取到 node 的 bin 目录")
    return None
  }

  // 路径：直接替换node为npm
  let name = @fs_ext.get_path_name(node_exe_path)
  let tool_path = @fs_ext.join_path(
    node_bin_dir,
    name.replace(old="node", new=tool.to_string()),
  )

  let node_dir = "\{node_bin_dir}/../"
  // npm和npx共用一个package.json
  let node_tool_name = if tool is Corepack {
    tool.to_string()
  } else {
    Npm.to_string()
  }
  let npm_package_json_file_path = "\{node_dir}/lib/node_modules/\{node_tool_name}/package.json"
  if @fs.exists(npm_package_json_file_path) {
    let json = @fs.read_file(npm_package_json_file_path).json()
    guard json is Object(map) else {
      @log.error("\{node_tool_name} 的 package.json 文件格式不对")
      return None
    }
    guard map.get("version") is Some(String(node_tool_version)) else {
      @log.error(
        "\{node_tool_name} 的 package.json 中的 version 格式不对",
      )
      return None
    }
    return Some((tool_path, node_tool_version))
  }
  @log.error("无法从 \{npm_package_json_file_path} 获取到 npm 的版本")
  None
}
