///|
/// 显示帮助信息
fn run_help() -> Unit {
  println(
    "mvm (Multi Version Manager) \{VERSION} —— One Tool to Manage Them All",
  )
  println("")
  println("用法:")
  println("  mvm <命令> [参数]")
  println("")
  println("命令:")
  let commands = [
    ("install, i", "安装指定版本", "mvm install node@20"),
    ("use", "设置全局版本", "mvm use node@20 / mvm use node"),
    ("pin", "项目级版本锁定", "mvm pin node@20"),
    ("uninstall, un", "卸载指定版本", "mvm uninstall node@18"),
    ("list, ls", "查看已安装版本", "mvm list node"),
    ("current", "查看当前使用版本", "mvm current [node]"),
    ("which", "查看工具路径", "mvm which node"),
    ("run", "临时运行指定版本", "mvm run node@18 -- node -v"),
    ("unuse", "移除全局版本设置", "mvm unuse node"),
    ("setup", "初始化工具脚本和PATH", "mvm setup [-p]"),
    (
      "upgrade", "升级 mvm 自身", "mvm upgrade / mvm upgrade -l / mvm upgrade -r",
    ),
    ("cache clean", "清理缓存", "mvm cache clean"),
    ("config", "查看/设置配置", "mvm config list / mvm config ls"),
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
    println("\{padded_name}\{padded_desc}\{example}")
  }
  println("")
  println("选项:")
  let options = [
    ("--help, -h", "显示帮助信息"),
    ("--version, -v", "显示版本号"),
    ("--skip-verify", "跳过 SHA256 校验（安装时使用）"),
    ("--no-cache", "不使用缓存，强制重新下载（安装时使用）"),
    ("--reinstall, -r", "重新安装当前版本（升级时使用）"),
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
    println("\{padded_opt}\{desc}")
  }
  println("")
  println("示例:")
  let examples = [
    ("mvm install node@lts", "安装 Node.js LTS 版本"),
    ("mvm install python@3.12", "安装 Python 3.12"),
    ("mvm install rust@stable", "安装 Rust stable 通道"),
    ("mvm install bun@1 --skip-verify", "跳过校验安装 Bun"),
    ("mvm install node@20 --no-cache", "不使用缓存重新安装 Node.js"),
    ("mvm pin node@20.18.0", "在项目中锁定 Node.js 版本"),
    (
      "mvm config set china", "一键配置中国大陆镜像（含 Python/Rust/Java 镜像）",
    ),
    ("mvm config set logo false", "关闭启动 logo 显示"),
    ("mvm upgrade --reinstall", "重新安装当前版本的 mvm"),
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
    println("\{padded_ex}\{desc}")
  }
}
