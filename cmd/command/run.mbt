///|
/// 判断是否应打印 logo：仅在 Help 和 Setup 命令中显示 logo，其他命令不显示
fn should_print_logo(command : Command) -> Bool {
  match command {
    Help | Setup(_) => true
    _ => false
  }
}

///|
/// 执行命令，返回 CommandResult（替代原 Unit 返回值）
/// logo 仅打印到控制台，不捕获到 CommandResult（logo 是品牌标识，不属于命令实际结果）
/// 子命令内部 raise fail(msg) 会被 catch 捕获，转为 CommandResult::failure
pub async fn run(command : Command) -> CommandResult {
  try {
    if should_print_logo(command) {
      // logo 仅打印到控制台，不写入 CommandResult.output
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
      LangInstall(path) => run_lang_install(path)
      LangList => run_lang_list()
      LangRemove(code) => run_lang_remove(code)
      LangSet(code) => run_lang_set(code)
    }
  } catch {
    e => {
      // 从 Error 中提取失败消息字符串
      let msg = match e {
        Failure::Failure(msg) => msg.trim().to_owned()
        e => e.to_string()
      }
      CommandResult::failure(msg)
    }
  }
}