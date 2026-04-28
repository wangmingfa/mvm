///|
using @tool_def {type Node, type Bun, type Zig}

///|
pub using @tool_def {
  type Tool,
  write_global_config,
  write_project_config,
  mvm_home,
  is_installed,
  tool_dir,
  version_dir,
  get_config,
}

///|
using @os {type OsInfo}

///|
fn parse_version(version : String) -> (String, Int) {
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
    _ => 0
  }
  return (version, version_count)
}

///|
pub async fn get_target_version(
  os : OsInfo,
  tool : Tool,
  version : String,
) -> String {
  let (version, version_count) = parse_version(version)
  match tool {
    Node => Node::get_target_version(os, version, version_count)
    Bun => Bun::get_target_version(os, version, version_count)
    Zig => Zig::get_target_version(os, version, version_count)
    _ => raise fail("暂不支持改工具：\{tool}")
  }
}

///|
pub fn match_version(
  tool : Tool,
  version : String,
  target_version : String,
) -> Bool {
  @log.debug(
    "tool: \{tool}, version: \{version}, target_version: \{target_version}",
  )
  match tool {
    Node | Zig | Bun => {
      let handle_version = if version.has_prefix("v") {
        version
      } else {
        "v\{version}"
      }
      if handle_version == target_version {
        return true
      }
      if target_version.has_prefix(handle_version) {
        let len = handle_version.length()
        let next_s = target_version[len:len + 1]
        let _ = @string.parse_int(next_s) catch { _ => return true }
        // 如果下一位是数字，则匹配不通过
        return false
      }
      false
    }
    _ => false
  }
}

///|
test "match_version" {
  inspect(
    match_version(Node, "18", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "v18", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "1", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Node, "v1", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Node, "18.20", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "v18.20", "v18.20.8"),
    content=(
      #|true
    ),
  )
  inspect(
    match_version(Node, "18.2", "v18.20.8"),
    content=(
      #|false
    ),
  )
  inspect(
    match_version(Bun, "1.3.12", "v1.3.12"),
    content=(
      #|true
    ),
  )
}

///|
/// 获取下载 URL
/// 返回值说明：(String, UInt)
///   String 为下载地址
///   UInt 为压缩包解压出来之后，需要进入多少层级才能到达实际工具根目录。一般的压缩包会有1层目录，某些压缩包没有包装一层根目录，返回0即可。
pub fn get_download_url(
  os_info : OsInfo,
  tool : Tool,
  version : String,
) -> (String, UInt) raise {
  match tool {
    Node => (Node::get_download_url(os_info, version), 1)
    Bun => (Bun::get_download_url(os_info, version), 1)
    Zig => (Zig::get_download_url(os_info, version), 1)
    _ => raise fail("无法获取 \{tool} 的下载链接")
  }
}

///|
/// 获取工具的运行路径，返回路径和版本
pub async fn _get_tool_exe_path(tool : Tool) -> (String, String)? {
  guard get_config(tool~) is Some((_, config)) &&
    config.get_value(tool) is Some(version) else {
    return None
  }
  let path = match tool {
    Node => Node::get_exe_path(version)
    Bun => Bun::get_exe_path(version)
    Zig => Zig::get_exe_path(version)
    _ => raise fail("不支持的工具：\{tool}")
  }
  Some((path, version))
}

///|
pub async fn get_tool_exe_path(tool : Tool) -> (String, String)? {
  let is_node_builtin_tools = @tool_def.Tool::is_node_builtin_tools(tool)
  // 如果是查找npm，实际上是去找Node
  let real_tool = if is_node_builtin_tools { @tool_def.Node } else { tool }
  let res = _get_tool_exe_path(real_tool)

  if is_node_builtin_tools {
    guard res is Some((path, _)) else { return None }
    return @tool_def.Node::get_node_builtin_tool_path_and_version(tool, path)
  }
  res
}

///|
pub async fn post_install(tool : Tool, target_dir : String) -> Unit {
  let os = @os.get_os_name()
  if os is Linux || os is MacOS {
    // 增加可执行权限
    let exe_files = match tool {
      Node =>
        ["node", "npm", "npx"].map(name => {
          @fs_ext.join_path(target_dir, "bin/\{name}")
        })
      Zig => [@fs_ext.join_path(target_dir, "zig")]
      Bun => [@fs_ext.join_path(target_dir, "bun")]
      _ => []
    }
    exe_files.insert(0, "+x")
    let _ = @process.run("chmod", exe_files)
  }
}
