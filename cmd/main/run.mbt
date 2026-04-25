///|
/// 执行命令
pub async fn run(command : Command) -> Unit {
  match command {
    Install(tool, version) => run_install(tool, version)
    Pin(tool, version) => run_pin(tool, version)
    Use(tool, version) => run_use(tool, version)
    List(tool_opt) => run_list(tool_opt)
    Uninstall(tool, version) => run_uninstall(tool, version)
  }
}
