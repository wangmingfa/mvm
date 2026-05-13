///|
pub enum Command {
  Help
  Version
  Upgrade
  Setup(Bool)
  Executor(Array[String])
  Install(Tool, String?)
  Pin(Tool, String)
  Use(Tool, String)
  List(Tool?)
  Uninstall(Tool, String?)
  Which(Tool)
  Run(Tool, String, Array[String])
  CacheClean
  ConfigList
  ConfigSet(String, String)
  ConfigPreset(String)
}

///|
pub impl Show for Command with to_string(s) {
  match s {
    Help => "Help"
    Version => "Version"
    Upgrade => "Upgrade"
    Setup(use_prefix) => "Setup(\{use_prefix})"
    Executor(args) => "Executor(\{args})"
    Install(tool, version) =>
      "Install(\{tool.to_string()}, \{@utils.option_to_string(version)})"
    Pin(tool, version) => "Pin(\{tool.to_string()}, \{version})"
    Use(tool, version) => "Use(\{tool.to_string()}, \{version})"
    List(Some(tool)) => "List(\{tool.to_string()})"
    List(None) => "List(All)"
    Uninstall(tool, version) =>
      "Uninstall(\{tool.to_string()}, \{@utils.option_to_string(version)})"
    Which(tool) => "Which(\{tool.to_string()})"
    Run(tool, version, args) => "Run(\{tool.to_string()}, \{version}, \{args})"
    CacheClean => "CacheClean"
    ConfigList => "ConfigList"
    ConfigSet(key, value) => "ConfigSet(\{key}, \{value})"
    ConfigPreset(name) => "ConfigPreset(\{name})"
  }
}

///|
pub impl Show for Command with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
fn Command::new_with_version(
  command_type : String,
  tool : String,
  version? : String,
) -> Command raise {
  let t = Tool::from_string(tool)
  match command_type {
    "install" => Install(t, version)
    "pin" => {
      guard version is Some(version) else {
        raise fail("pin参数无效。示例：mvm pin node@20")
      }
      Pin(t, version)
    }
    "use" => {
      guard version is Some(version) else {
        raise fail("use参数无效。示例：mvm use node@20")
      }
      Use(t, version)
    }
    "uninstall" => Uninstall(t, version)
    _ => raise fail("无效的命令类型：\{command_type}")
  }
}

///|
fn parse_with_version(command_type : String, options : String) -> Command raise {
  match options.split("@").to_array() {
    [before, after] =>
      Command::new_with_version(
        command_type,
        before.to_owned(),
        version=after.to_owned(),
      )
    [tool] => Command::new_with_version(command_type, tool.to_owned())
    _ => raise fail("无效的参数 \{options}")
  }
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  match argv {
    ["--help"] | ["-h"] | [] => Help
    ["--version"] | ["-v"] => Version
    ["upgrade"] => Upgrade
    ["setup"] => Setup(false)
    ["setup", "--prefix"] => Setup(true)
    ["setup", "-p"] => Setup(true)
    ["executor", .. args] => Executor(args.to_owned())
    ["install", options] | ["i", options] =>
      parse_with_version("install", options)
    ["pin", options] => parse_with_version("pin", options)
    ["use", options] => parse_with_version("use", options)
    ["uninstall", options] | ["un", options] =>
      parse_with_version("uninstall", options)
    ["which"] =>
      raise fail("请指定要查看的工具。示例：mvm which node")
    ["which", tool] => Which(Tool::from_string(tool))
    ["which", ..] =>
      raise fail(
        "which 命令只接受一个工具参数。示例：mvm which node",
      )
    ["run"] =>
      raise fail(
        "请指定要运行的工具和版本。示例：mvm run node@18 -- node -v",
      )
    ["run", tool_version, "--", .. run_args] =>
      match tool_version.split("@").to_array() {
        // 支持：node@18
        [tool, version] => {
          let t = Tool::from_string(tool.to_owned())
          Run(t, version.to_owned(), run_args.to_owned())
        }
        // 也支持不传版本号（自动根据运行目录获取版本号）：node
        [tool] => {
          let t = Tool::from_string(tool.to_owned())
          Run(t, "", run_args.to_owned())
        }
        _ =>
          raise fail(
            "无效的版本格式。示例：mvm run node@18 -- node -v",
          )
      }
    ["run", ..] =>
      raise fail(
        "请使用 -- 分隔版本和命令。示例：mvm run node@18 -- node -v",
      )
    ["list"] | ["ls"] => List(None)
    ["list", tool] | ["ls", tool] => List(Some(Tool::from_string(tool)))
    ["cache", "clean"] => CacheClean
    ["cache"] => raise fail("请使用 mvm cache clean 清理缓存")
    ["cache", ..] =>
      raise fail("不支持的 cache 子命令。请使用 mvm cache clean")
    ["config", "list"] | ["config", "ls"] | ["config", "l"] => ConfigList
    ["config"] => raise fail("请使用 mvm config list 查看配置")
    ["config", "set", key, value] => ConfigSet(key, value)
    ["config", "set", preset] => ConfigPreset(preset)
    ["config", "set", ..] => {
      let url = "https://cdn.gh-proxy.org/" + "$" + "URL"
      raise fail(
        "config set 命令需要提供 key 和 value。示例：mvm config set github_proxy " +
        url,
      )
    }
    ["config", subcommand, ..] =>
      raise fail("不支持的 config 子命令：\{subcommand}")
    [cmd] => raise fail("命令 '\{cmd}' 缺少参数")
    _ => {
      let msg = argv.join(" ")
      raise fail("无效的命令：\{msg}")
    }
  }
}

///|
fn[T : Show] get_arg_value_from_args(
  args : Array[T],
  key : String,
  default? : String,
) -> String? {
  let find_arg_key = "--\{key}"
  let find_arg_key_with_equal = "\{find_arg_key}="
  for idx, arg in args {
    let arg_str = arg.to_string()
    if arg_str == find_arg_key {
      return args.get(idx + 1).map(v => v.to_string())
    }
    if arg_str.has_prefix(find_arg_key_with_equal) {
      return Some(arg_str[find_arg_key_with_equal.length():].to_owned())
    }
  }
  if default is Some(default) {
    return Some(default)
  }
  None
}

///|
pub fn get_arg_value(key : String, default? : String) -> String? {
  let args = @env.args()[1:].to_owned()
  if default is Some(default) {
    return get_arg_value_from_args(args, key, default~)
  }
  get_arg_value_from_args(args, key)
}

///|
test "get_arg_value" {
  let args = [
    "--log-level=debug", // key=value
     "--node", "24", // key value
  ]
  debug_inspect(
    get_arg_value_from_args(args, "log-level"),
    content=(
      #|Some("debug")
    ),
  )
  debug_inspect(
    get_arg_value_from_args(args, "node"),
    content=(
      #|Some("24")
    ),
  )
  debug_inspect(
    get_arg_value_from_args(args, "zig", default="v0.15.1"),
    content=(
      #|Some("v0.15.1")
    ),
  )
}
