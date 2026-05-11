///|
/// 执行命令
pub async fn run(command : Command) -> Unit {
  match command {
    Version => run_version()
    Upgrade => run_upgrade()
    Executor(args) => run_executor(args)
    Install(tool, version) => run_install(tool, version)
    Pin(tool, version) => run_pin(tool, version)
    Use(tool, version) => run_use(tool, version)
    List(tool_opt) => run_list(tool_opt)
    Uninstall(tool, version) => run_uninstall(tool, version)
    Which(tool) => run_which(tool)
    Run(tool, version, args) => run_run(tool, version, args)
    CacheClean => run_cache_clean()
    ConfigList => run_config()
    ConfigSet(key, value) => run_config_set(key, value)
    ConfigPreset(name) => run_config_preset(name)
  }
}
