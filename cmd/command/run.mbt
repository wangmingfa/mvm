///|
/// 判断是否应打印 logo：Run 命令不打印，配置 logo=false 时不打印
fn should_print_logo(command : Command, config : @tools.GlobalConfig) -> Bool {
  // Run 是工具直接调用，不需要打印 logo
  match command {
    Run(_, _, _) => false
    _ =>
      // config.logo 为 Some(false) 时隐藏 logo，其他情况（None 或 Some(true））显示
      config.logo != Some(false)
  }
}

///|
/// 执行命令
pub async fn run(command : Command) -> Unit {
  let (_, config) = @tools.get_global_config()
  if should_print_logo(command, config) {
    @utils.print_logo()
  }
  match command {
    Help => run_help()
    Version => run_version()
    Upgrade(version, reinstall) => run_upgrade(version, reinstall)
    UpgradeList => run_upgrade_list()
    Setup(use_prefix) => run_setup(use_prefix)
    Install(tool, version, skip_verify, no_cache) =>
      run_install(tool, version, skip_verify, no_cache)
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