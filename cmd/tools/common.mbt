///|
pub async fn get_target_version(
  os : @os.OsInfo,
  tool : Tool,
  version : String,
) -> String {
  match tool {
    Node => get_target_nodejs_version(os, version)
    _ => raise fail("暂不支持改工具：\{tool}")
  }
}

///|
pub fn match_version(
  tool : Tool,
  version : String,
  target_version : String,
) -> Bool {
  match tool {
    Node => {
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
}

///|
/// 获取下载 URL
pub fn get_download_url(
  os_info : @os.OsInfo,
  tool : Tool,
  version : String,
) -> (String, UInt) raise {
  match tool {
    Node => (get_nodejs_download_url(os_info, version), 1)
    // Bun =>
    //   "https://github.com/oven-sh/bun/releases/download/bun-v\{version}/bun-\{os}-\{arch}.zip"
    Zig => {
      let arch = if os_info.arch is Aarch64 { "aarch64" } else { "x86_64" }
      let (os, ext) = match os_info.name {
        Windows => ("windows", "zip")
        Linux => ("linux", "tar.gz")
        MacOS => ("darwin", "tar.gz")
        name => raise fail("不支持的操作系统：\{name}")
      }
      (
        "https://ziglang.org/download/\{version}/zig-\{os}-\{arch}-\{version}.\{ext}",
        0,
      )
    }
    Npm =>
      // npm 随 node 安装，不单独下载
      raise fail("暂不支持npm")
  }
}

///|
pub async fn get_tool_exe_path(tool : Tool) -> (String, String)? {
  guard get_config(tool~) is Some((_, config)) &&
    config.get_value(Node) is Some(version) else {
    return None
  }
  let path = match tool {
    Node => get_nodejs_exe_path(version)
    _ => raise fail("不支持的工具：\{tool}")
  }
  Some((path, version))
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
      _ => []
    }
    exe_files.insert(0, "+x")
    let _ = @process.run("chmod", exe_files)
  }
}
