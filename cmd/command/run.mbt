///|
fn should_print_logo(command : Command) -> Bool {
  match command {
    Executor(_) | Run(_, _, _) => false
    _ => true
  }
}

///|
/// 执行命令
pub async fn run(command : Command) -> Unit {
  if should_print_logo(command) {
    @utils.print_logo()
  }
  match command {
    Help => run_help()
    Version => run_version()
    Upgrade => run_upgrade()
    Setup(use_prefix) => run_setup(use_prefix)
    Executor(args) => run_executor(args)
    Install(tool, version) => run_install(tool, version)
    Pin(tool, version) => run_pin(tool, version)
    Use(tool, version) => run_use(tool, version)
    Unuse(tool) => run_unuse(tool)
    List(tool_opt) => run_list(tool_opt)
    Uninstall(tool, version) => run_uninstall(tool, version)
    Which(tool) => run_which(tool)
    Current(tool_opt) => run_current(tool_opt)
    Run(tool, version, args) => run_run(tool, version, args)
    CacheClean => run_cache_clean()
    ConfigList => run_config()
    ConfigSet(key, value) => run_config_set(key, value)
    ConfigPreset(name) => run_config_preset(name)
  }
}
