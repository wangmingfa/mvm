///|
/// 显示帮助信息
fn run_help() -> CommandResult {
  let result = CommandResult::success()
  // 标题
  print_to(result, @i18n.t("help.title", args={ "VERSION": VERSION }))
  print_to(result, "")
  // 用法
  print_to(result, @i18n.t("help.usage"))
  print_to(result, "  \{@i18n.t("help.usage_detail")}")
  print_to(result, "")
  // 命令
  print_to(result, @i18n.t("help.commands"))
  let commands = [
    ("install, i", @i18n.t("help.cmd_install"), "mvm install node@20"),
    ("use", @i18n.t("help.cmd_use"), "mvm use node@20 / mvm use node"),
    ("pin", @i18n.t("help.cmd_pin"), "mvm pin node@20"),
    ("uninstall, un", @i18n.t("help.cmd_uninstall"), "mvm uninstall node@18"),
    ("list, ls", @i18n.t("help.cmd_list"), "mvm list node"),
    ("current", @i18n.t("help.cmd_current"), "mvm current [node]"),
    ("which", @i18n.t("help.cmd_which"), "mvm which node"),
    ("run", @i18n.t("help.cmd_run"), "mvm run node@18 -- node -v"),
    ("unuse", @i18n.t("help.cmd_unuse"), "mvm unuse node"),
    ("setup", @i18n.t("help.cmd_setup"), "mvm setup [-p]"),
    ("upgrade", @i18n.t("help.cmd_upgrade"), "mvm upgrade / mvm upgrade -l / mvm upgrade -r"),
    ("cache clean", @i18n.t("help.cmd_cache_clean"), "mvm cache clean"),
    ("config", @i18n.t("help.cmd_config"), "mvm config list / mvm config ls"),
    ("lang", @i18n.t("help.cmd_lang"), "mvm lang set zh / mvm lang list / mvm lang install ./ja.json"),
  ]
  let mut max_name_w = 0
  let mut max_desc_w = 0
  for cmd in commands {
    let (name, desc, _) = cmd
    let nw = @utils.display_width(name)
    let dw = @utils.display_width(desc)
    if nw > max_name_w {
      max_name_w = nw
    }
    if dw > max_desc_w {
      max_desc_w = dw
    }
  }
  for cmd in commands {
    let (name, desc, example) = cmd
    let padded_name = @utils.pad_right("  " + name, max_name_w + 4)
    let padded_desc = @utils.pad_right(desc, max_desc_w + 2)
    print_to(result, "\{padded_name}\{padded_desc}\{example}")
  }
  print_to(result, "")
  // 选项
  print_to(result, @i18n.t("help.options"))
  let options = [
    ("--help, -h", @i18n.t("help.opt_help")),
    ("--version, -v", @i18n.t("help.opt_version")),
    ("--skip-verify", @i18n.t("help.opt_skip_verify")),
    ("--no-cache", @i18n.t("help.opt_no_cache")),
    ("--reinstall, -r", @i18n.t("help.opt_reinstall")),
  ]
  let mut max_opt_w = 0
  for opt_item in options {
    let (opt, _) = opt_item
    let ow = @utils.display_width(opt)
    if ow > max_opt_w {
      max_opt_w = ow
    }
  }
  for opt_item in options {
    let (opt, desc) = opt_item
    let padded_opt = @utils.pad_right("  " + opt, max_opt_w + 4)
    print_to(result, "\{padded_opt}\{desc}")
  }
  print_to(result, "")
  // 示例
  print_to(result, @i18n.t("help.examples"))
  let examples = [
    ("mvm install node@lts", @i18n.t("help.ex_install_node_lts")),
    ("mvm install python@3.12", @i18n.t("help.ex_install_python")),
    ("mvm install rust@stable", @i18n.t("help.ex_install_rust")),
    ("mvm install bun@1 --skip-verify", @i18n.t("help.ex_install_bun_skip")),
    ("mvm install node@20 --no-cache", @i18n.t("help.ex_install_node_nocache")),
    ("mvm pin node@20.18.0", @i18n.t("help.ex_pin_node")),
    ("mvm config set china", @i18n.t("help.ex_config_china")),
    ("mvm upgrade --reinstall", @i18n.t("help.ex_upgrade_reinstall")),
  ]
  let mut max_ex_w = 0
  for ex_item in examples {
    let (ex, _) = ex_item
    let ew = @utils.display_width(ex)
    if ew > max_ex_w {
      max_ex_w = ew
    }
  }
  for ex_item in examples {
    let (ex, desc) = ex_item
    let padded_ex = @utils.pad_right("  " + ex, max_ex_w + 4)
    print_to(result, "\{padded_ex}\{desc}")
  }
  result
}