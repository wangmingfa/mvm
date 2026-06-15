///| 阿里云node.js镜像
// const NODE_RELEASE_URL = "https://mirrors.aliyun.com/nodejs-release"

///|
const NODE_RELEASE_URL = "https://nodejs.org/dist"

///|
const NODE_INDEX_URL = "https://nodejs.org/dist/index.json"

///|
const NODE_INDEX_CACHE_FILE = "nodejs_index.json"

///|
// 存储当前安装是否使用 Rosetta 2 回退到 x64 版本
// 在 _check_os_compatiable 中设置，在 get_download_info 和 get_expected_checksum 中读取
let node_use_rosetta_fallback : Ref[Bool] = Ref(false)

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
    raise fail(
      @i18n.t("error.version_info_format_wrong", args={ "tool": "Node.js" }),
    )
  }
  // for index, item in arr {
  //   println("\{index}: \{item}")
  //   let _ : NodeJsInfo = @json.from_json(item)
  // }
  let nodeJsInfos : Array[NodeJsInfo] = arr.map(v => {
    @json.from_json(v) catch {
      e =>
        raise fail(
          @i18n.t("error.parse_version_info_failed", args={
            "tool": "Node.js",
            "reason": e.to_string(),
          }),
        )
    }
  })
  guard nodeJsInfos.length() > 0 else {
    raise fail(@i18n.t("error.version_info_empty", args={ "tool": "Node.js" }))
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
        raise fail(
          @i18n.t("error.version_not_found_detail", args={ "version": "lts" }),
        )
      }
      Node::_check_os_compatiable(
        os,
        nodeJsInfos[idx],
        error_msg_tpl=@i18n.t("error.version_os_arch_unsupported"),
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
            raise fail(
              @i18n.t("error.version_not_found_detail", args={
                "version": version,
              }),
            )
          }
          Node::_check_os_compatiable(os, nodeJsInfos[idx])
        }
        _ =>
          raise fail(
            @i18n.t("error.invalid_version_detail", args={ "version": version }),
          )
      }
  }
}

///|
fn Node::_check_os_compatiable(
  os : @os.OsInfo,
  nodeJsInfo : NodeJsInfo,
  error_msg_tpl? : String = @i18n.t("error.version_os_arch_unsupported"),
) -> String raise {
  // 判断当前操作系统、架构的文件是否支持
  let file_prefix = [
    match os.name {
      Windows => "win"
      MacOS => "osx"
      Linux => "linux"
      name =>
        raise fail(
          @i18n.t("error.unsupported_os_detail", args={
            "name": name.to_string(),
          }),
        )
    },
    match os.arch {
      Aarch64 => "arm64"
      X86 => "x86"
      X86_64 => "x64"
      arch =>
        raise fail(
          @i18n.t("error.unsupported_arch", args={ "arch": arch.to_string() }),
        )
    },
  ].join("-")
  let { version, files, .. } = nodeJsInfo
  if files.all(v => !v.has_prefix(file_prefix)) {
    // macOS ARM 支持通过 Rosetta 2 运行 x64 版本
    if os.name is MacOS && os.arch is Aarch64 {
      let x64_prefix = "osx-x64"
      if files.any(v => v.has_prefix(x64_prefix)) {
        // 只在首次设置回退标志时打印警告，避免重复提示
        if !node_use_rosetta_fallback.val {
          @log.warn(
            @i18n.t("node.warn_rosetta_fallback", args={
              "version": version,
              "arch": "arm64",
            }),
          )
          // 标记使用 Rosetta 回退，供 get_download_info 和 get_expected_checksum 读取
          node_use_rosetta_fallback.val = true
        }
        return version
      }
    }
    raise fail(format_os_compat_error(error_msg_tpl, version, os))
  }
  // 有原生版本支持，重置回退标志
  node_use_rosetta_fallback.val = false
  version
}

///|
/// 获取 Node.js 的下载信息（URL 和 headers）
pub fn Node::get_download_info(
  os_info : @os.OsInfo,
  version : String,
) -> DownloadInfo raise {
  // macOS ARM 使用 Rosetta 回退时，强制使用 x64 架构
  let arch = if os_info.arch is Aarch64 && !node_use_rosetta_fallback.val {
    "arm64"
  } else {
    "x64"
  }
  let (os, ext) = match os_info.name {
    Windows => ("win", "zip")
    Linux => ("linux", "tar.gz")
    MacOS => ("darwin", "tar.gz")
    name =>
      raise fail(
        @i18n.t("error.unsupported_os_detail", args={ "name": name.to_string() }),
      )
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
  // macOS ARM 使用 Rosetta 回退时，强制使用 x64 架构
  let arch = if os_info.arch is Aarch64 && !node_use_rosetta_fallback.val {
    "arm64"
  } else {
    "x64"
  }
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
          @i18n.t("node.cannot_fetch_shasums", args={
            "url": @utils.blue(shasums_url),
            "code": res.code.to_string(),
            "reason": res.reason,
          }),
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
  @log.debug(
    @i18n.t("node.debug_get_exe_info_entry", args={
      "program": program,
      "version": version,
    }),
  )
  let node_path = NodePath(version)
  let { lib: lib_dir, bin: bin_dir, .. } = node_path
  let program_path = node_path.get_exe_path(program)
  // node是否存在
  let node_exists = @fs.exists(node_path.get_exe_path(Node.to_string()))
  // 路径信息日志
  @log.debug(
    @i18n.t("node.debug_node_path_info", args={
      "lib_dir": lib_dir,
      "bin_dir": bin_dir,
      "program_path": program_path,
    }),
  )
  @log.debug(
    @i18n.t("node.debug_program_exists", args={
      "path": program_path,
      "exists": node_exists.to_string(),
    }),
  )
  match program {
    "node" => {
      @log.debug(
        @i18n.t("node.debug_returning_node_info", args={
          "path": program_path,
          "exists": node_exists.to_string(),
        }),
      )
      return ProgramExeInfo(
        program,
        program_path,
        version,
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
      @log.debug(
        @i18n.t("node.debug_searching_node_modules", args={
          "dir": lib_node_modules_dir,
        }),
      )
      // 检查 node_modules 目录是否存在
      if !@fs.exists(lib_node_modules_dir) {
        @log.debug(
          @i18n.t("node.debug_node_modules_not_exists", args={
            "dir": lib_node_modules_dir,
          }),
        )
        return ProgramExeInfo(
          program,
          program_path,
          version,
          version,
          envs={},
          false,
          Tool::Node,
          node_exists,
        )
      }
      let libs = @fs.readdir(lib_node_modules_dir)
      @log.debug(
        @i18n.t("node.debug_found_packages", args={
          "count": libs.length().to_string(),
          "dir": lib_node_modules_dir,
        }),
      )
      lib_loop~: for lib in libs {
        // 有的npm包有多层目录，比如@google/gemini-cli，他在node_modules下是一个@google目录，@google目录下才是gemini-cli包，所以要特殊处理一下
        let (lib_path, package_json_path) = for path = @fs_ext.join_path(
                                                    lib_node_modules_dir, lib,
                                                  ) {
          @log.debug(
            @i18n.t("node.debug_searching_in", args={
              "path": @utils.yellow(path),
            }),
          )
          let package_json_path = @fs_ext.join_path(path, "package.json")
          if @fs.exists(package_json_path) {
            @log.debug("找到package.json: \{package_json_path}")
            break (path, package_json_path)
          }
          let subs = @fs.readdir(path)
          if subs.length() == 1 {
            continue @fs_ext.join_path(path, subs[0])
          }
          // 有多个文件夹，不再继续查找
          continue lib_loop~
        } nobreak {
          @log.debug(
            @i18n.t("node.debug_no_package_json_found_in", args={
              "dir": @utils.yellow(path),
            }),
          )
          continue lib_loop~
        }
        @log.debug(
          "找到包的根目录: \{lib_path}, package.json路径: \{package_json_path}",
        )
        let json = @fs.read_file(package_json_path).json() catch {
          e => {
            // 解析JSON失败
            @log.warn(
              @i18n.t("node.parse_json_failed", args={
                "path": package_json_path,
                "reason": e.to_string(),
              }),
            )
            continue
          }
        }
        guard json is Object(map) else {
          // JSON不是对象
          @log.warn(
            @i18n.t("node.parse_json_not_object", args={
              "path": package_json_path,
            }),
          )
          continue
        }
        let pkg_version = match map.get("version") {
          Some(String(v)) => v
          _ => {
            // 没有version字段
            @log.warn(
              @i18n.t("node.parse_json_no_version", args={
                "path": package_json_path,
              }),
            )
            continue
          }
        }
        let bin = map.get("bin")
        guard bin is Some(Object(bin_map)) else {
          // 没有bin字段
          @log.warn(
            @i18n.t("node.parse_json_no_bin", args={ "path": package_json_path }),
          )
          continue
        }
        // 记录 bin_map 中的所有命令名
        let bin_keys = bin_map.keys().map(k => k).join(", ")
        @log.debug(
          @i18n.t("node.debug_bin_keys", args={ "pkg": lib, "keys": bin_keys }),
        )
        for key, value in bin_map {
          if key == program {
            @log.debug(
              @i18n.t("node.debug_program_matched", args={
                "program": program,
                "pkg": lib,
              }),
            )
            // 从 package.json 的 bin 字段提取实际的可执行文件路径
            let bin_relative_path = match value {
              String(s) => s
              _ => {
                @log.debug(
                  @i18n.t("node.debug_bin_value_not_string", args={
                    "program": program,
                    "pkg": lib,
                  }),
                )
                continue
              }
            }
            // 构建实际的可执行文件路径：lib/node_modules/<pkg>/<bin_path>
            let actual_bin_path = @fs_ext.join_path(lib_path, bin_relative_path)
            @log.debug(
              @i18n.t("node.debug_actual_bin_path", args={
                "path": actual_bin_path,
              }),
            )
            // 检查实际的可执行文件是否存在
            if !@fs.exists(actual_bin_path) {
              @log.warn(
                @i18n.t("node.debug_bin_path_not_exists", args={
                  "program": program,
                  "path": actual_bin_path,
                  "pkg_json": package_json_path,
                }),
              )
              continue
            }
            // 在windows下，无需使用node_modules里面的文件，而是直接使用node根目录的cmd文件进行运行
            let program_path = match @os.get_os_name() {
              Windows => @fs_ext.join_path(bin_dir, program + ".cmd")
              _ => actual_bin_path
            }
            return ProgramExeInfo(
              program,
              program_path,
              pkg_version,
              version,
              envs={},
              true,
              Tool::Node,
              node_exists,
            )
          }
        }
      }
      // 找不到可执行文件信息，返回 program_exists=false 的结构体
      @log.debug(
        @i18n.t("node.exe_info_not_found", args={
          "program": program,
          "version": version,
        }),
      )
      ProgramExeInfo(
        program,
        program_path,
        version,
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
/// 从node内的文件路径获取NodePath
/// 比如：/Users/xxx/.mvm-test/tools/node/v24.16.0/lib/node_modules/npm/bin/npm-cli.js -> /Users/xxx/.mvm-test/tools/node/v24.16.0
///   或者：/Users/xxx/.mvm-test/tools/node/v24.16.0/lib/node_modules -> /Users/xxx/.mvm-test/tools/node/v24.16.0
pub fn Node::get_node_path_by_node_inner_path(
  node_inner_path : String,
) -> NodePath raise {
  let node_inner_path = @fs_ext.canonicalize_path(node_inner_path)
  @log.debug("node_inner_path: \{node_inner_path}")
  let node_tool_root_path = tool_dir(Node)
  // 先判断前缀
  guard node_inner_path.has_prefix(node_tool_root_path) is true else {
    raise fail(@i18n.t("error.invalid_path", args={ "path": node_inner_path }))
  }
  // 一直往上级目录找
  let node_root_dir = for dir = node_inner_path
                          @fs_ext.get_parent_dir(dir) is Some(parent_dir)
                          dir = parent_dir {
    // 如果上级目录与node_tool_root_path相等，则表示当前dir就是node的根目录
    if parent_dir == node_tool_root_path {
      break dir
    }
  } nobreak {
    raise fail(@i18n.t("error.invalid_path", args={ "path": node_inner_path }))
  }

  // 从node_dir中提取版本号（目录名）
  let version = @fs_ext.get_path_name(node_root_dir)

  // 使用版本号构造NodeDir
  NodePath(version)
}

///|
/// 准备 Node 运行命令的参数
/// 如果程序是 .js 文件，需要用同版本的 node 来执行，避免 shebang 递归调用问题
pub fn Node::prepare_run_command(
  program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> (String, Array[String]) {
  let { path, extra_args, tool_version, .. } = program_exe_info
  // 如果程序不是 .js 文件，直接使用原始路径和参数
  if !path.has_suffix(".js") {
    return (path, [..extra_args, ..exec_args])
  }
  // .js 文件需要用同版本的 node 来执行
  // 通过版本号构造 NodePath 获取 node 可执行文件路径
  let node_exe = try {
    let node_path = NodePath(tool_version)
    @fs_ext.join_path(node_path.bin, "node")
  } catch {
    _ => {
      @log.warn(
        @i18n.t("node.warn_cannot_get_node_exe", args={
          "version": tool_version,
        }),
      )
      "node"
    }
  }
  @log.debug(
    @i18n.t("node.debug_js_file_use_node", args={
      "js_file": path,
      "node_exe": node_exe,
    }),
  )
  (node_exe, [path, ..exec_args])
}

///|
pub async fn Node::before_command(
  program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Map[String, String]? {
  let { name, path, .. } = program_exe_info
  match name {
    "npm" => Npm::before_npm_command(path, exec_args)
    _ => None
  }
}

///|
pub async fn Node::after_command(
  before_run_result : Map[String, String]?,
  program_exe_info : ProgramExeInfo,
  exec_args : ArrayView[String],
) -> Unit {
  let { name, path, .. } = program_exe_info
  match name {
    "npm" => Npm::after_npm_command(before_run_result, path, exec_args)
    _ => ()
  }
}