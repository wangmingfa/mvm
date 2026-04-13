// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
pub enum Tool {
  Node
  Npm
  Bun
  Zig
}

///|
impl Show for Tool with to_string(s) {
  match s {
    Bun => "Bun"
    Npm => "Npm"
    Node => "Node"
    Zig => "Zig"
  }
}

///|
impl Show for Tool with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
fn Tool::from_string(tool : String) -> Tool raise {
  match tool.to_lower() {
    "node" => Node
    "npm" => Npm
    "bun" => Bun
    "zig" => Zig
    _ => raise fail("无效的工具：\{tool}")
  }
}

///|
pub struct Version(String)

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
}

///|
pub impl Show for Command with to_string(s) {
  match s {
    Install(tool, version) | Pin(tool, version) =>
      "Install(\{tool.to_string()}, \{version.to_string()})"
  }
}

///|
pub impl Show for Command with output(s, logger) {
  logger.write_string(s.to_string())
}

///|
fn Command::new(
  command_type : String,
  tool : String,
  version : String,
) -> Command raise {
  match command_type {
    "install" => return Install(Tool::from_string(tool), Version(version))
    "pin" => Pin(Tool::from_string(tool), Version(version))
    _ => raise fail("无效的命令类型：\{command_type}")
  }
}

///|
fn parse(command_type : String, options : String) -> Command raise {
  lexmatch options {
    (before, "@", after) =>
      Command::new(command_type, before.to_string(), after.to_string())
    _ => raise fail("无效的参数：\{options}")
  }
}

///|
pub fn get_command(argv : ArrayView[String]) -> Command raise {
  match argv {
    [command_type, options] => parse(command_type, options)
    [_] => raise fail("缺失参数")
    _ => {
      let msg = argv.join(" ")
      raise fail("无效的命令：\{msg}")
    }
  }
}
