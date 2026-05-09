///|
const GITHUB_REPO = "wangmingfa/mvm"

///|
const GITHUB_API_LATEST = "https://api.github.com/repos/\{GITHUB_REPO}/releases/latest"

///|
const INSTALL_SH = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/install.sh"

///|
const INSTALL_PS1 = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/install.ps1"

///|
/// 执行 upgrade 命令
pub async fn run_upgrade() -> Unit {
  @log.info("正在检查最新版本...")
  let latest = fetch_latest_version()
  if latest.is_blank() {
    @log.error("无法获取最新版本信息，请检查网络连接")
    return
  }
  @log.info(
    "当前版本：\{@utils.yellow(VERSION)}，最新版本：\{@utils.yellow(latest)}",
  )
  if latest == VERSION {
    @log.success("已是最新版本，无需升级")
    return
  }
  @log.info("正在升级到 \{@utils.yellow(latest)}...")
  let code = match @os.get_os_name() {
    Windows =>
      @process.run("powershell", [
        "-Command",
        "& ([scriptblock]::Create((irm \{INSTALL_PS1}))) --online",
      ])
    _ =>
      @process.run("bash", [
        "-c",
        "curl -fsSL \{INSTALL_SH} | bash -s -- --online",
      ])
  }
  match code {
    0 => @log.success("升级成功！当前版本：\{latest}")
    _ => @log.error("升级失败，请尝试手动执行安装命令")
  }
}

///|
/// 从 GitHub API 获取最新 release 版本号
async fn fetch_latest_version() -> String {
  let (code, output) = @process.collect_stdout("curl", [
    "-sL",
    "-H",
    "Accept: application/vnd.github+json",
    GITHUB_API_LATEST,
  ]) catch {
    _ => return ""
  }
  if code != 0 {
    return ""
  }
  let body = output.text()
  // 从 JSON 中提取 "tag_name": "vX.Y.Z"
  let prefix = "\"tag_name\":"
  guard body.find(prefix) is Some(start) else { return "" }
  let after = body[start + prefix.length():]
  guard after.find("\"") is Some(q1) else { return "" }
  let tag_start = after[q1 + 1:]
  guard tag_start.find("\"") is Some(q2) else { return "" }
  tag_start[:q2].to_owned()
}
