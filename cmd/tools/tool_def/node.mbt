///| 阿里云node.js镜像
// const NODE_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
const NODE_RELEASE_URL = "https://nodejs.org/dist"

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
  get_target_version_with_cache(
    NODE_INDEX_CACHE_FILE,
    NODE_INDEX_URL,
    "Node.js",
    os, version, version_count,
    Node::_get_proper_version,
  )
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
    "" | "lts" => {
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
    raise fail(format_os_compat_error(error_msg_tpl, version, os))
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
pub fn Node::get_exe_path(version : String) -> String raise {
  let os = @os.get_os_name()
  let sub_dir = if os is Windows { "" } else { "bin" }
  let suffix = if os is Windows { ".exe" } else { "" }
  [version_dir(Tool::Node, version), sub_dir, "node\{suffix}"]
  .filter(v => !v.is_blank())
  .join("/")
}

///|
/// 获取node内置工具的路径，比如：npm、npx、corepack等
pub async fn Node::get_node_builtin_tool_path_and_version(
  tool : Tool,
  node_tool_exe : ToolExe,
) -> ToolExe? {
  let { path: node_exe_path, .. } = node_tool_exe

  // 处理node内置工具

  guard @fs_ext.get_parent_dir(node_exe_path) is Some(node_bin_dir) else {
    @log.error("无法获取到 node 的 bin 目录")
    return None
  }

  // 路径：直接替换node为对应工具名称
  let name = @fs_ext.get_path_name(node_exe_path)
  let os = @os.get_os_name()
  // 如果是windows，则需要将exe转为ps1后缀
  let old = if os is Windows { "node.exe" } else { "node" }
  let tool_ext = if os is Windows { ".ps1" } else { "" }
  let tool_path = @fs_ext.join_path(
    node_bin_dir,
    name.replace(old~, new="\{tool}\{tool_ext}"),
  )

  let { root: node_dir, lib: lib_dir, .. } = Node::get_node_dir(node_exe_path)
  // npm和npx共用一个package.json
  let node_tool_name = if tool is Corepack {
    tool.to_string()
  } else {
    Npm.to_string()
  }
  let node_tool_package_json_file_path = "\{lib_dir}/node_modules/\{node_tool_name}/package.json"
  let node_tool_version = if @fs.exists(node_tool_package_json_file_path) {
    let json = @fs.read_file(node_tool_package_json_file_path).json()
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
    // return Some(
    //   ToolExe::new_node_builtin_tool(
    //     tool,
    //     node_tool_exe,
    //     tool_path,
    //     node_tool_version,
    //     envs={ "NPM_CONFIG_PREFIX": node_dir },
    //   ),
    // )
    node_tool_version
  } else {
    ""
  }
  // @log.error(
  //   "无法从 \{node_tool_package_json_file_path} 获取到 \{tool} 的版本",
  // )
  // None
  Some(
    ToolExe::new_node_builtin_tool(
      tool,
      node_tool_exe,
      tool_path,
      node_tool_version,
      envs={ "NPM_CONFIG_PREFIX": node_dir },
    ),
  )
}

///|
/// 获取npm全局安装的第三方包的路径和版本
pub async fn Node::get_npm_global_pkg_path_and_version(
  npm_pkg_name : String,
  node_tool_exe : ToolExe,
) -> NpmPkgExe? {
  // 在 node 的 bin 目录下查找与包名同名的软连接
  let node_dir = Node::get_node_dir(node_tool_exe.path)

  @log.debug("node目录 \{node_dir.to_string()}")

  let bin_file_path = node_dir.get_bin_file_path(npm_pkg_name)

  let target_path = match @os.get_os_name() {
    MacOS | Linux => {
      // MacOS和linux使用的是软连接
      let symlink_path = bin_file_path
      if !@fs.exists(symlink_path) {
        raise fail(
          "NPM 包 \{npm_pkg_name} 在 node@\{node_tool_exe.version} 未安装",
        )
      }

      @log.debug("NPM包 \{npm_pkg_name} 的运行文件路径 \{symlink_path}")

      // 解析软连接得到实际文件路径
      let target_path = match @fs_ext.readlink_target(symlink_path) {
        Some(s) => {
          @log.debug("获取到的实际文件路径 \{s}")
          // 如果目标路径是相对路径，拼接 bin 目录
          if s.has_prefix("/") {
            s
          } else {
            node_dir.join_with_bin([s])
          }
        }
        None => raise fail("无法解析软连接 \{symlink_path} 的目标")
      }
      target_path
    }
    Windows =>
      // windows下是直接运行的node的bin目录下的xxx.ps1
      bin_file_path
    _ => raise fail("不支持的操作系统")
  }

  @log.debug(
    "NPM包 \{npm_pkg_name} 的实际运行文件路径 \{target_path}",
  )

  let pkg_root_dir = node_dir.get_pkg_root_dir(npm_pkg_name)

  // 读取 package.json 获取版本号
  let pkg_json_path = @fs_ext.join_path(pkg_root_dir, "package.json")
  if !@fs.exists(pkg_json_path) {
    @log.debug(
      "NPM 包 \{npm_pkg_name} 的 package.json 不存在：\{pkg_json_path}",
    )
    raise fail(
      "NPM 包 \{npm_pkg_name} 在 node@\{node_tool_exe.version} 未安装",
    )
  }

  let json = @fs.read_file(pkg_json_path).json()
  guard json is Object(map) else {
    raise fail("NPM 包 \{npm_pkg_name} 的 package.json 格式不对")
  }
  let version = match map.get("version") {
    Some(String(v)) => v
    _ =>
      raise fail(
        "NPM 包 \{npm_pkg_name} 的 package.json 中缺少 version 字段",
      )
  }

  let target_path = @fs_ext.canonicalize_path(target_path)
  Some({ path: target_path, version })
}

///|
pub struct NpmPkgExe {
  // 包的可执行文件路径
  path : String
  // 包的版本
  version : String
} derive(Debug)

///|
/// 在MacOS、Linux下：root下面有lib和bin目录
/// 在windows下，这三个个相等
pub struct NodeDir {
  root : String
  lib : String
  bin : String
}

///|
fn NodeDir::to_string(self : Self) -> String {
  let { root, lib, bin } = self
  "root: \{root}, lib: \{lib}, bin: \{bin}"
}

///|
pub fn Node::get_node_dir(exe_path : String) -> NodeDir raise {
  let os = @os.get_os_name()
  guard @fs_ext.get_parent_dir(exe_path) is Some(node_bin_dir) else {
    raise fail("无法获取到 node 的 bin 目录")
  }
  // windows下的node_bin_dir和node_dir是一样的，linux和mac下node_bin_dir是node_dir/bin
  let node_dir = if os is Windows {
    node_bin_dir
  } else {
    @fs_ext.join_path(node_bin_dir, "../")
  }
  // windows下，没有lib目录，直接在node_dir下找
  let lib_dir = if os is Windows {
    node_dir
  } else {
    @fs_ext.join_path(node_dir, "lib")
  }
  { root: node_dir, lib: lib_dir, bin: node_bin_dir }
}

///|
/// 获取某个包的根目录，可以为npm、corepack以及npm安装的全局包
pub fn NodeDir::get_pkg_root_dir(self : Self, pkg_name : String) -> String {
  @fs_ext.join_paths([self.lib, "node_modules", pkg_name])
}

///|
/// 获取文件的二进制目录，返回bin目录下的文件路径
pub fn NodeDir::get_bin_file_path(self : Self, file_name : String) -> String {
  let os = @os.get_os_name()
  let ext = if os is Windows { ".ps1" } else { "" }
  @fs_ext.join_paths([self.bin, file_name + ext])
}

///|
pub fn NodeDir::join_with_bin(self : Self, paths : ArrayView[String]) -> String {
  @fs_ext.join_paths([self.bin, ..paths])
}