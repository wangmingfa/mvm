///|
pub enum Command {
  Help
  Version
  Upgrade(String?, Bool) // 可指定升级目标版本号，None 表示升级到最新版；Bool 为是否重新安装当前版本
  UpgradeList // 查询所有可用的 mvm 版本
  Setup(Bool)
  Install(Tool, String?, Bool, Bool) // 第一个 Bool 为是否跳过 SHA256 校验，第二个 Bool 为是否不使用缓存
  Pin(Tool, String)
  Use(Tool, String?)
  Unuse(Tool)
  List(Tool?)
  Uninstall(Tool, String?)
  Which(Tool)
  Current(Tool?)
  Run(Tool, String, Array[String])
  CacheClean
  ConfigList
  ConfigSet(String, String)
  ConfigPreset(String)
} derive(Debug)

///|
pub impl Show for Command with to_string(s) {
  match s {
    Help => "Help"
    Version => "Version"
    Upgrade(version, reinstall) => "Upgrade(\{@utils.option_to_string(version)}, reinstall=\{reinstall})"
    UpgradeList => "UpgradeList"
    Setup(use_prefix) => "Setup(\{use_prefix})"
    Install(tool, version, skip_verify, no_cache) =>
      "Install(\{tool.to_string()}, \{@utils.option_to_string(version)}, skip_verify=\{skip_verify}, no_cache=\{no_cache})"
    Pin(tool, version) => "Pin(\{tool.to_string()}, \{version})"
    Use(tool, version) =>
      "Use(\{tool.to_string()}, \{@utils.option_to_string(version)})"
    Unuse(tool) => "Unuse(\{tool.to_string()})"
    List(Some(tool)) => "List(\{tool.to_string()})"
    List(None) => "List(All)"
    Uninstall(tool, version) =>
      "Uninstall(\{tool.to_string()}, \{@utils.option_to_string(version)})"
    Which(tool) => "Which(\{tool.to_string()})"
    Current(Some(tool)) => "Current(\{tool.to_string()})"
    Current(None) => "Current(All)"
    Run(tool, version, args) =>
      "Run(\{tool.to_string()}, \{version}, \{to_repr(args)})"
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
  skip_verify? : Bool = false,
  no_cache? : Bool = false,
) -> Command raise {
  let t = Tool::from_string(tool)
  match command_type {
    "install" => Install(t, version, skip_verify, no_cache)
    "pin" => {
      guard version is Some(version) else {
        raise fail("pin参数无效。示例：mvm pin node@20")
      }
      Pin(t, version)
    }
    "use" => Use(t, version)
    "uninstall" => Uninstall(t, version)
    _ => raise fail("无效的命令类型：\{command_type}")
  }
}

///|
fn parse_with_version(
  command_type : String,
  options : String,
  skip_verify? : Bool = false,
  no_cache? : Bool = false,
) -> Command raise {
  match options.split("@").to_array() {
    [before, after] =>
      Command::new_with_version(
        command_type,
        before.to_owned(),
        version=after.to_owned(),
        skip_verify~,
        no_cache~,
      )
    [tool] =>
      Command::new_with_version(
        command_type,
        tool.to_owned(),
        skip_verify~,
        no_cache~,
      )
    _ => raise fail("无效的参数 \{options}")
  }
}

///|
/// 从参数数组中提取 install 命令的 flags，返回 (skip_verify, no_cache, 剩余位置参数)
fn _extract_install_flags(
  args : ArrayView[String],
) -> (Bool, Bool, Array[String]) {
  let mut skip_verify = false
  let mut no_cache = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "--skip-verify" => skip_verify = true
      "--no-cache" => no_cache = true
      _ => positional.push(arg)
    }
  }
  (skip_verify, no_cache, positional)
}

///|
/// 从参数数组中提取 upgrade 命令的 flags，返回 (reinstall, 剩余位置参数)
fn _extract_upgrade_flags(
  args : ArrayView[String],
) -> (Bool, Array[String]) {
  let mut reinstall = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "--reinstall" | "-r" => reinstall = true
      _ => positional.push(arg)
    }
  }
  (reinstall, positional)
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  // 处理 install/i 命令（支持灵活的 flag 位置）
  if argv.length() >= 2 && (argv[0] == "install" || argv[0] == "i") {
    let (skip_verify, no_cache, positional) = _extract_install_flags(argv[1:])
    match positional.length() {
      0 =>
        raise fail("请指定要安装的工具。示例：mvm install node@20")
      1 =>
        return parse_with_version(
          "install",
          positional[0],
          skip_verify~,
          no_cache~,
        )
      _ =>
        raise fail(
          "install 命令只接受一个工具参数。示例：mvm install node@20",
        )
    }
  }
  // 处理 upgrade 命令（支持 --reinstall/-r flag 和灵活的参数位置）
  if argv.length() >= 2 && argv[0] == "upgrade" {
    let (reinstall, positional) = _extract_upgrade_flags(argv[1:])
    match positional.length() {
      0 => return Upgrade(None, reinstall)
      1 => {
        let arg = positional[0]
        // --list/-l 查看版本列表，不是升级操作
        if arg == "--list" || arg == "-l" {
          return UpgradeList
        }
        return Upgrade(Some(arg), reinstall)
      }
      _ =>
        raise fail(
          "upgrade 命令参数无效。示例：mvm upgrade 或 mvm upgrade v1.0.0 --reinstall",
        )
    }
  }
  match argv {
    ["--help"] | ["-h"] | [] => Help
    ["--version"] | ["-v"] => Version
    ["upgrade"] => Upgrade(None, false)
    ["setup"] => Setup(false)
    ["setup", "--prefix"] => Setup(true)
    ["setup", "-p"] => Setup(true)
    ["pin", options] => parse_with_version("pin", options)
    ["use", options] => parse_with_version("use", options)
    ["unuse"] =>
      raise fail("请指定要移除的工具。示例：mvm unuse node")
    ["unuse", tool] => Unuse(Tool::from_string(tool))
    ["unuse", ..] =>
      raise fail(
        "unuse 命令只接受一个工具参数。示例：mvm unuse node",
      )
    ["uninstall", options] | ["un", options] =>
      parse_with_version("uninstall", options)
    ["which"] =>
      raise fail("请指定要查看的工具。示例：mvm which node")
    ["which", tool] => Which(Tool::from_string(tool))
    ["which", ..] =>
      raise fail(
        "which 命令只接受一个工具参数。示例：mvm which node",
      )
    ["current"] => Current(None)
    ["current", tool] => Current(Some(Tool::from_string(tool)))
    ["current", ..] =>
      raise fail(
        "current 命令只接受一个工具参数。示例：mvm current node",
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
            "无效的版本格式 \{tool_version}。示例：mvm run node@18 -- node -v",
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

// =====================
// get_command 命令解析测试
// =====================

///|
test "get_command: 基本命令" {
  // 无参数 → Help
  guard (try? get_command([])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Help))
  // --help → Help
  guard (try? get_command(["--help"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Help))
  // -h → Help
  guard (try? get_command(["-h"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Help))
  // --version → Version
  guard (try? get_command(["--version"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Version))
  // -v → Version
  guard (try? get_command(["-v"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Version))
}

///|
test "get_command: install 命令" {
  // install node@20
  guard (try? get_command(["install", "node@20"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), false, false)),
  )
  // i node@20 (缩写)
  guard (try? get_command(["i", "node@20"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), false, false)),
  )
  // install node (无版本号)
  guard (try? get_command(["install", "node"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, None, false, false)),
  )
  // install node@20 --skip-verify
  guard (try? get_command(["install", "node@20", "--skip-verify"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, false)),
  )
  // install node@20 --no-cache
  guard (try? get_command(["install", "node@20", "--no-cache"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), false, true)),
  )
  // install node@20 --skip-verify --no-cache
  guard (try? get_command(["install", "node@20", "--skip-verify", "--no-cache"]))
    is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, true)),
  )
  // install bun@lts
  guard (try? get_command(["install", "bun@lts"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Bun, Some("lts"), false, false)),
  )
  // install go@1.23
  guard (try? get_command(["install", "go@1.23"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Go, Some("1.23"), false, false)),
  )
}

///|
test "get_command: install 灵活 flag 位置" {
  // --skip-verify 在工具参数前
  guard (try? get_command(["install", "--skip-verify", "node@20"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, false)),
  )
  // --no-cache 在工具参数前
  guard (try? get_command(["install", "--no-cache", "node@20"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), false, true)),
  )
  // 两个 flag 在工具参数前
  guard (try? get_command(["install", "--skip-verify", "--no-cache", "node@20"]))
    is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, true)),
  )
  // flag 在前和在后的组合
  guard (try? get_command(["install", "--no-cache", "node@20", "--skip-verify"]))
    is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, true)),
  )
  // 缩写 i 也支持灵活位置
  guard (try? get_command(["i", "--skip-verify", "node@20"])) is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(Install(Node, Some("20"), true, false)),
  )
}

///|
test "get_command: use/pin/unuse 命令" {
  // use node@20
  guard (try? get_command(["use", "node@20"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Use(Node, Some("20"))))
  // use node (无版本号)
  guard (try? get_command(["use", "node"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Use(Node, None)))
  // pin node@20.18.0
  guard (try? get_command(["pin", "node@20.18.0"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Pin(Node, "20.18.0")))
  // unuse node
  guard (try? get_command(["unuse", "node"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Unuse(Node)))
}

///|
test "get_command: list/current/which 命令" {
  // list
  guard (try? get_command(["list"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(List(None)))
  // ls (缩写)
  guard (try? get_command(["ls"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(List(None)))
  // list node
  guard (try? get_command(["list", "node"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(List(Some(Node))))
  // current
  guard (try? get_command(["current"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Current(None)))
  // current node
  guard (try? get_command(["current", "node"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Current(Some(Node))))
  // which node
  guard (try? get_command(["which", "node"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Which(Node)))
}

///|
test "get_command: run 命令" {
  // run node@18 -- node -v
  guard (try? get_command(["run", "node@18", "--", "node", "-v"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Run(Node, "18", ["node", "-v"])))
  // run node -- npm -v (无版本号)
  guard (try? get_command(["run", "node", "--", "npm", "-v"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Run(Node, "", ["npm", "-v"])))
}

///|
test "get_command: upgrade 命令" {
  // upgrade（升级到最新版）
  guard (try? get_command(["upgrade"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(None, false)))
  // upgrade v1.0.0（升级到指定版本）
  guard (try? get_command(["upgrade", "v1.0.0"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(Some("v1.0.0"), false)))
  // upgrade --list（查看版本列表）
  guard (try? get_command(["upgrade", "--list"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(UpgradeList))
  // upgrade -l（查看版本列表）
  guard (try? get_command(["upgrade", "-l"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(UpgradeList))
  // upgrade --reinstall（重新安装当前版本）
  guard (try? get_command(["upgrade", "--reinstall"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(None, true)))
  // upgrade -r（重新安装当前版本，缩写）
  guard (try? get_command(["upgrade", "-r"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(None, true)))
  // upgrade --reinstall v1.0.0（重新安装指定版本）
  guard (try? get_command(["upgrade", "--reinstall", "v1.0.0"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(Some("v1.0.0"), true)))
  // upgrade v1.0.0 --reinstall（flag 在后）
  guard (try? get_command(["upgrade", "v1.0.0", "--reinstall"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Upgrade(Some("v1.0.0"), true)))
}

///|
test "get_command: setup/cache/config 命令" {
  // setup
  guard (try? get_command(["setup"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Setup(false)))
  // setup --prefix
  guard (try? get_command(["setup", "--prefix"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Setup(true)))
  // setup -p
  guard (try? get_command(["setup", "-p"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(Setup(true)))
  // cache clean
  guard (try? get_command(["cache", "clean"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(CacheClean))
  // config list
  guard (try? get_command(["config", "list"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(ConfigList))
  // config ls
  guard (try? get_command(["config", "ls"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(ConfigList))
  // config set github_proxy https://example.com/$URL
  guard (try? get_command([
      "config", "set", "github_proxy", "https://example.com/$URL",
    ]))
    is Ok(cmd)
  debug_inspect(
    cmd,
    content=@debug.to_string(
      ConfigSet("github_proxy", "https://example.com/$URL"),
    ),
  )
  // config set china (预设)
  guard (try? get_command(["config", "set", "china"])) is Ok(cmd)
  debug_inspect(cmd, content=@debug.to_string(ConfigPreset("china")))
}

///|
test "get_command: 错误命令" {
  // unuse 无参数 → 报错
  guard (try? get_command(["unuse"])) is Err(_)
  // which 无参数 → 报错
  guard (try? get_command(["which"])) is Err(_)
  // run 无参数 → 报错
  guard (try? get_command(["run"])) is Err(_)
  // run 缺少 -- 分隔 → 报错
  guard (try? get_command(["run", "node@18", "node", "-v"])) is Err(_)
  // 不存在的命令 → 报错
  guard (try? get_command(["foobar"])) is Err(_)
  // pin 无版本号 → 报错
  guard (try? get_command(["pin", "node"])) is Err(_)
}
