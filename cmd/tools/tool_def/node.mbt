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
    os,
    version,
    version_count,
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
/// 获取 Node.js 的下载信息（URL 和 headers）
pub fn Node::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  let arch = if os_info.arch is Aarch64 { "arm64" } else { "x64" }
  let (os, ext) = match os_info.name {
    Windows => ("win", "zip")
    Linux => ("linux", "tar.gz")
    MacOS => ("darwin", "tar.gz")
    name => raise fail("不支持的操作系统：\{name}")
  }
  let url = "\{NODE_RELEASE_URL}/\{version}/node-\{version}-\{os}-\{arch}.\{ext}"
  { url, headers: {}, root_path_depth: 1 }
}

///|
/// 获取 Node.js 的预期 SHA256 校验值
/// 从 https://nodejs.org/dist/v{version}/SHASUMS256.txt 获取
pub async fn Node::get_expected_checksum(
  os_info : @os.OsInfo,
  version : String,
) -> String? {
  // 构建归档文件名（与 get_download_url 一致）
  let arch = if os_info.arch is Aarch64 { "arm64" } else { "x64" }
  let (os, ext) = match os_info.name {
    Windows => ("win", "zip")
    Linux => ("linux", "tar.gz")
    MacOS => ("darwin", "tar.gz")
    _ => return None
  }
  let archive_filename = "node-\{version}-\{os}-\{arch}.\{ext}"

  // 构建 SHASUMS256.txt URL
  let shasums_url = "\{NODE_RELEASE_URL}/\{version}/SHASUMS256.txt"

  // 应用镜像/代理配置
  let (_, global_config) = get_global_config()
  let ctx = UrlReplaceContext::new(shasums_url, "node", version, os, arch)
  let shasums_url = apply_global_config(shasums_url, global_config, ctx)

  // 尝试从缓存读取
  let cache_file = "node_shasums_\{version}.txt"
  let cached_content = read_cache_file_content(cache_file)
  let shasums_content = match cached_content {
    Some(content) => content
    None => {
      // 从远程获取
      let (res, data) = @http.get(
        shasums_url,
        headers=@request.merge_detault_headers(),
      )
      if !(res.code is (200..<300)) {
        // 无法获取校验文件
        @log.warn(
          @i18n.t("node.cannot_fetch_shasums", args={ "url": @utils.blue(shasums_url), "code": res.code.to_string(), "reason": res.reason }),
        )
        return None
      }
      let content = data.text()
      write_cache_file_content(cache_file, content)
      content
    }
  }

  // 解析 SHASUMS256.txt，查找匹配的文件名
  // 格式: <hash>  <filename> (两个空格分隔)
  _parse_node_shasums(shasums_content, archive_filename)
}

///|
/// 解析 Node.js SHASUMS256.txt 文件内容
/// 格式: <hash>  <filename>
fn _parse_node_shasums(content : String, filename : String) -> String? {
  let lines = content.split("\n")
  for line in lines {
    let line = line.trim().to_owned()
    if line.is_blank() {
      continue
    }
    // 用两个空格分隔，格式: <hash>  <filename>
    let parts = line.split("  ").to_array()
    if parts.length() >= 2 {
      let hash = parts[0].trim().to_owned().to_lower()
      let name = parts[1].trim().to_owned()
      if name == filename {
        return Some(hash)
      }
    }
  }
  None
}

///|
pub async fn Node::get_program_exe_info(
  program : String,
  version : String,
) -> ProgramExeInfo {
  // 请指定program或version
  if program.is_blank() || version.is_blank() {
    raise fail(@i18n.t("node.specify_program_or_version"))
  }
  // 入口日志：记录请求参数
  @log.debug(@i18n.t("node.debug_get_exe_info_entry", args={ "program": program, "version": version }))
  let node_path = NodePath(version)
  let { lib: lib_dir, bin: bin_dir, .. } = node_path
  let program_path = node_path.get_exe_path(program)
  let node_exists = @fs.exists(program_path)
  // 路径信息日志
  @log.debug(@i18n.t("node.debug_node_path_info", args={ "lib_dir": lib_dir, "bin_dir": bin_dir, "program_path": program_path }))
  @log.debug(@i18n.t("node.debug_program_exists", args={ "path": program_path, "exists": node_exists.to_string() }))
  match program {
    "node" => {
      @log.debug(@i18n.t("node.debug_returning_node_info", args={ "path": program_path, "exists": node_exists.to_string() }))
      return ProgramExeInfo(
        program,
        program_path,
        version,
        envs={},
        node_exists,
        Tool::Node,
        node_exists,
      )
    }
    _ => {
      // 运行的程序不一定能对应到lib目录下的包，例如：
      //   vite安装后，程序名称就是vite
      //   docsify-cli安装后，程序名称是docsify
      // 所以要去lib目录下找所有的包，找到对应的bin目录，去找有没有这个程序
      let lib_node_modules_dir = @fs_ext.join_path(lib_dir, "node_modules")
      @log.debug(@i18n.t("node.debug_searching_node_modules", args={ "dir": lib_node_modules_dir }))
      // 检查 node_modules 目录是否存在
      if !@fs.exists(lib_node_modules_dir) {
        @log.debug(@i18n.t("node.debug_node_modules_not_exists", args={ "dir": lib_node_modules_dir }))
        return ProgramExeInfo(
          program,
          program_path,
          version,
          envs={},
          false,
          Tool::Node,
          node_exists,
        )
      }
      let libs = @fs.readdir(lib_node_modules_dir)
      @log.debug(@i18n.t("node.debug_found_packages", args={ "count": libs.length().to_string(), "dir": lib_node_modules_dir }))
      for lib in libs {
        let lib_path = @fs_ext.join_path(lib_node_modules_dir, lib)
        // 从lib_path中查找
        @log.debug(@i18n.t("node.debug_searching_in", args={ "path": @utils.yellow(lib_path) }))
        if @fs.kind(lib_path) is Directory {
          let package_json_path = @fs_ext.join_path(lib_path, "package.json")
          guard @fs.exists(package_json_path) else {
            @log.debug(@i18n.t("node.debug_no_package_json", args={ "path": lib_path }))
            continue
          }
          let json = @fs.read_file(package_json_path).json() catch {
            e => {
              // 解析JSON失败
              @log.warn(@i18n.t("node.parse_json_failed", args={ "path": package_json_path, "reason": e.to_string() }))
              continue
            }
          }
          guard json is Object(map) else {
            // JSON不是对象
            @log.warn(@i18n.t("node.parse_json_not_object", args={ "path": package_json_path }))
            continue
          }
          let version = match map.get("version") {
            Some(String(v)) => v
            _ => {
                // 没有version字段
              @log.warn(@i18n.t("node.parse_json_no_version", args={ "path": package_json_path }))
              continue
            }
          }
          let bin = map.get("bin")
          guard bin is Some(Object(bin_map)) else {
            // 没有bin字段
            @log.warn(@i18n.t("node.parse_json_no_bin", args={ "path": package_json_path }))
            continue
          }
          // 记录 bin_map 中的所有命令名
          let bin_keys = bin_map.keys().map(k => k).join(", ")
          @log.debug(@i18n.t("node.debug_bin_keys", args={ "pkg": lib, "keys": bin_keys }))
          for key, _ in bin_map {
            if key == program {
              @log.debug(@i18n.t("node.debug_program_matched", args={ "program": program, "pkg": lib }))
              // let bin_path = match value {
              //   String(s) => @fs_ext.join_path(lib, s)
              //   Object(map) =>
              //     match map.get("default") {
              //       Some(String(s)) => @fs_ext.join_path(lib, s)
              //       _ => continue
              //     }
              //   _ => continue
              // }
              // let bin_path = @fs_ext.join_path(lib_dir, bin_path)
              // guard @fs.exists(bin_path) else {
              //   @log.warn(
              //     "程序 \{program} 在 \{package_json_path} 中声明的路径 \{bin_path} 不存在",
              //   )
              //   continue
              // }
              return ProgramExeInfo(
                program,
                program_path,
                version,
                envs={},
                true,
                Tool::Node,
                node_exists,
              )
            }
          }
        }
      }
      // 找不到可执行文件信息，返回 program_exists=false 的结构体
      @log.debug(@i18n.t("node.exe_info_not_found", args={ "program": program, "version": version }))
      ProgramExeInfo(
        program,
        program_path,
        version,
        envs={},
        false,
        Tool::Node,
        node_exists,
      )
    }
  }
}

///|
/// 在MacOS、Linux下：root下面有lib和bin目录
/// 在windows下，这三个个相等
pub struct NodePath {
  root : String
  lib : String
  bin : String
}

///|
fn NodePath::NodePath(version : String) -> NodePath raise {
  let node_dir = version_dir(Tool::Node, version)
  let os = @os.get_os_name()
  // windows下的node_bin_dir和node_dir是一样的，linux和mac下node_bin_dir是node_dir/bin
  let node_bin_dir = if os is Windows {
    node_dir
  } else {
    @fs_ext.join_path(node_dir, "bin")
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
pub fn NodePath::get_pkg_root_dir(self : Self, pkg_name : String) -> String {
  @fs_ext.join_paths([self.lib, "node_modules", pkg_name])
}

///|
/// 获取文件的二进制目录，返回bin目录下的文件路径
pub fn NodePath::get_bin_file_path(self : Self, file_name : String) -> String {
  let os = @os.get_os_name()
  let ext = if os is Windows { ".ps1" } else { "" }
  @fs_ext.join_paths([self.bin, file_name + ext])
}

///|
pub fn NodePath::join_with_bin(
  self : Self,
  paths : ArrayView[String],
) -> String {
  @fs_ext.join_paths([self.bin, ..paths])
}

///|
fn NodePath::get_exe_path(self : Self, program : String) -> String {
  let bin_dir = self.bin
  let os = @os.get_os_name()
  let is_node = program is "node"
  let suffix = match os {
    Windows => if is_node { ".exe" } else { ".ps1" }
    _ => ""
  }
  @fs_ext.join_paths([bin_dir, program + suffix].filter(v => !v.is_blank()))
}

///|
/// 从npm可执行文件路径获取NodeDir
pub fn Node::get_node_dir(npm_exe_path : String) -> NodePath raise {
  // npm通常位于Node的bin目录下
  // Windows: node_dir/npm.exe
  // macOS/Linux: node_dir/bin/npm
  let os = @os.get_os_name()
  let node_dir = if os is Windows {
    // Windows下直接取父目录
    @fs_ext.get_parent_dir(npm_exe_path)
  } else {
    // macOS/Linux下取bin目录的父目录
    let bin_dir = @fs_ext.get_parent_dir(npm_exe_path)
    match bin_dir {
      Some(bin_dir) => @fs_ext.get_parent_dir(bin_dir)
      None => None
    }
  }

  // 无法推断Node安装目录
  guard node_dir is Some(node_dir) else {
    raise fail(@i18n.t("node.cannot_infer_install_dir", args={ "path": npm_exe_path }))
  }

  // 从node_dir中提取版本号（目录名）
  let version = @fs_ext.get_path_name(node_dir)

  // 使用版本号构造NodeDir
  NodePath(version)
}