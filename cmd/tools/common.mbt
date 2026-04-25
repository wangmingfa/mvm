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
pub fn get_tool_exe_path(tool : Tool) -> String raise {
  match tool {
    Node => get_nodejs_exe_path()
    _ => raise fail("不支持的工具：\{tool}")
  }
}

///|
/// 写入项目配置
pub async fn write_project_config(tool : Tool, version : String) -> Unit {
  let config = read_project_config()
  let config = if config is Some(config) {
    let json = config.to_json()
    guard json is Object(map) else { {} }
    map
  } else {
    {}
  }
  let key = tool.to_string()
  let value = version
  config.set(key, Json::string(value))
  let content = Json::object(config).stringify(indent=2)
  @fs.write_file(project_config_file(), content)
}
