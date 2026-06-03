///|
using @command {get_command, run}

///|
async fn main {
  guard @env.current_dir() is Some(_dir) else {
    raise fail(@i18n.t("error.no_current_dir"))
  }
  // 从 GlobalConfig 读取 language 设置，初始化 i18n
  let (_, config) = @tools.get_global_config()
  // 设置外部语言字典目录（MVM_HOME/langs）
  @i18n.set_langs_dir(@fs_ext.join_path(@tools.mvm_home(), "langs"))
  @i18n.init_lang(config.language)

  let args = @env.args()
  let arg_str = @utils.yellow(args)
  @log.debug(@i18n.t("main.debug_running", args={ "args": arg_str }))
  // get_command 可能 raise，run 内部已捕获错误返回 CommandResult
  try {
    let command = get_command(args[1:])
    let result = run(command)
    if result.error is Some(err) {
      // 错误信息打印到 stderr
      @log.println_error(Failure::Failure(err))
    }
    if result.exit_code != 0 {
      @sys.exit(result.exit_code)
    }
  } catch {
    e => {
      @log.println_error(e)
      @sys.exit(1)
    }
  }
}
