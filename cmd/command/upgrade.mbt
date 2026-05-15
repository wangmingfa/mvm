///|
const GITHUB_REPO = "wangmingfa/mvm"

///|
const GITHUB_API_LATEST = "https://api.github.com/repos/\{GITHUB_REPO}/releases/latest"

///|
const INSTALL_SH = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/scripts/install_online.sh"

///|
const INSTALL_PS1 = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/scripts/install_online.ps1"

///|
/// 规范化版本号：不以 v 开头时自动补齐
fn normalize_version(version : String) -> String {
  if version.has_prefix("v") { version } else { "v\{version}" }
}

///|
/// 执行 upgrade 命令，可指定目标版本
pub async fn run_upgrade(version : String?) -> Unit {
  // 确定目标版本：指定版本直接使用，未指定则获取最新版本
  let target_version = match version {
    Some(v) => normalize_version(v)
    None => {
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
      latest
    }
  }
  @log.info("正在升级到 \{@utils.yellow(target_version)}...")
  // 使用 install_online 脚本升级；指定版本时通过 MVM_VERSION 环境变量传递
  let code = match @os.get_os_name() {
    Windows => {
      // 指定版本时设置 MVM_VERSION 环境变量，安装完成后清理
      let cmd = match version {
        Some(_) =>
          "$env:MVM_VERSION='\{target_version}'; irm \{INSTALL_PS1}|iex; Remove-Item Env:MVM_VERSION"
        None => "irm \{INSTALL_PS1}|iex"
      }
      @process.run("powershell", ["-c", cmd])
    }
    _ => {
      let cmd = match version {
        Some(_) =>
          "export MVM_VERSION='\{target_version}'; curl -fsSL \{INSTALL_SH} | bash"
        None => "curl -fsSL \{INSTALL_SH} | bash"
      }
      @process.run("bash", ["-c", cmd])
    }
  }
  match code {
    0 => @log.success("升级成功！当前版本：\{target_version}")
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
