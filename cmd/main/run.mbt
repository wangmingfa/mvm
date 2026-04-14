///|
/// 执行命令
pub async fn run(command : @lib.Command) -> Unit {
  match command {
    @lib.Install(tool, version) => run_install(tool, version)
    @lib.Pin(tool, version) => run_pin(tool, version)
    @lib.Use(tool, version) => run_use(tool, version)
    @lib.List(tool_opt) => run_list(tool_opt)
    @lib.Uninstall(tool, version) => run_uninstall(tool, version)
  }
}
