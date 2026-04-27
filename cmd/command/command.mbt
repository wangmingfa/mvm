///|
using @tools {type Tool}

///|
pub struct Version(String)

///|
pub fn Version::new(version : String) -> Self {
  Version(version)
}

///|
/// 获取版本号字符串
pub fn Version::value(self : Version) -> String {
  self.0
}

///|
impl Show for Version with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for Version with to_string(s) {
  "Version(\"\{s.0}\")"
}

///|
pub enum Command {
  Install(Tool, Version)
  Pin(Tool, Version)
  Use(Tool, Version)
  List(Tool?)
  Uninstall(Tool, Version)
}

///|
pub impl Show for Command with to_string(s) {
  match s {
    Install(tool, version) =>
      "Install(\{tool.to_string()}, \{version.to_string()})"
    Pin(tool, version) => "Pin(\{tool.to_string()}, \{version.to_string()})"
    Use(tool, version) => "Use(\{tool.to_string()}, \{version.to_string()})"
    List(Some(tool)) => "List(\{tool.to_string()})"
    List(None) => "List(All)"
    Uninstall(tool, version) =>
      "Uninstall(\{tool.to_string()}, \{version.to_string()})"
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
  version : String,
) -> Command raise {
  let t = Tool::from_string(tool)
  let v = Version(version)
  match command_type {
    "install" => Install(t, v)
    "pin" => Pin(t, v)
    "use" => Use(t, v)
    "uninstall" => Uninstall(t, v)
    _ => raise fail("无效的命令类型：\{command_type}")
  }
}

///|
fn parse_with_version(command_type : String, options : String) -> Command raise {
  lexmatch options {
    (before, "@", after) =>
      Command::new_with_version(
        command_type,
        before.to_string(),
        after.to_string(),
      )
    _ => raise fail("无效的参数：\{options}，格式应为 tool@version")
  }
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  match argv {
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
      return Some(arg_str[find_arg_key_with_equal.length():].to_string())
    }
  }
  if default is Some(default) {
    return Some(default)
  }
  None
}

///|
pub fn get_arg_value(key : String, default? : String) -> String? {
  let args = @env.args()[1:].to_array()
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
