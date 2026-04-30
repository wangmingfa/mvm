///|
using @tools {type Tool}

///|
pub enum Command {
  Executor(Array[String])
  Install(Tool, String?)
  Pin(Tool, String)
  Use(Tool, String)
  List(Tool?)
  Uninstall(Tool, String?)
}

///|
pub impl Show for Command with to_string(s) {
  match s {
    Executor(args) => "Executor(\{args})"
    Install(tool, version) =>
      "Install(\{tool.to_string()}, \{@utils.option_to_string(version)})"
    Pin(tool, version) => "Pin(\{tool.to_string()}, \{version})"
    Use(tool, version) => "Use(\{tool.to_string()}, \{version})"
    List(Some(tool)) => "List(\{tool.to_string()})"
    List(None) => "List(All)"
    Uninstall(tool, version) =>
      "Uninstall(\{tool.to_string()}, \{@utils.option_to_string(version)})"
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
  lexmatch options {
    (before, "@", after) =>
      Command::new_with_version(
        command_type,
        before.to_owned(),
        version=after.to_owned(),
      )
    tool => Command::new_with_version(command_type, tool.to_owned())
  }
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  match argv {
    ["executor", .. args] => Executor(args.to_owned())
    ["install", options] | ["i", options] =>
      parse_with_version("install", options)
    ["pin", options] => parse_with_version("pin", options)
    ["use", options] => parse_with_version("use", options)
    ["uninstall", options] | ["un", options] =>
      parse_with_version("uninstall", options)
    ["list"] | ["ls"] => List(None)
    ["list", tool] | ["ls", tool] => List(Some(Tool::from_string(tool)))
    [cmd] => raise fail("命令 '\{cmd}' 缺少参数")
    [] => raise fail("请提供命令参数。示例：mvm install node@22")
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
  inspect(
    get_arg_value_from_args(args, "log-level"),
    content=(
      #|Some("debug")
    ),
  )
  inspect(
    get_arg_value_from_args(args, "node"),
    content=(
      #|Some("24")
    ),
  )
  inspect(
    get_arg_value_from_args(args, "zig", default="v0.15.1"),
    content=(
      #|Some("v0.15.1")
    ),
  )
}
