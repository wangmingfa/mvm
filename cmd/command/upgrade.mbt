///|
const GITHUB_REPO = "wangmingfa/mvm"

///|
const GITHUB_API_LATEST = "https://api.github.com/repos/\{GITHUB_REPO}/releases/latest"

///|
const INSTALL_SH = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/scripts/install_online.sh"

///|
const INSTALL_PS1 = "https://raw.githubusercontent.com/\{GITHUB_REPO}/main/scripts/install_online.ps1"

///|
const GITHUB_API_RELEASES = "https://api.github.com/repos/\{GITHUB_REPO}/releases"

///|
/// 规范化版本号：不以 v 开头时自动补齐
fn normalize_version(version : String) -> String {
  if version.has_prefix("v") {
    version
  } else {
    "v\{version}"
  }
}

///|
/// 检查指定版本是否存在于 GitHub releases
async fn check_version_exists(version : String) -> Bool {
  // 通过 GitHub releases/tags API 验证版本是否存在，返回 200 表示存在，404 表示不存在
  let url = "https://api.github.com/repos/\{GITHUB_REPO}/releases/tags/\{version}"
  let (res, _) = @http.get(url, headers=@request.merge_detault_headers()) // 网络错误时 res.code 不会是 200，等同于版本不存在
  res.code == 200
}

///|
/// 执行 upgrade 命令，可指定目标版本；reinstall 为 true 时重新安装当前版本
pub async fn run_upgrade(version : String?, reinstall : Bool) -> Unit {
  // 确定目标版本：指定版本需验证存在性，未指定则获取最新版本
  let target_version = match version {
    Some(v) => {
      let v = normalize_version(v)
      @log.info("正在验证版本 \{@utils.yellow(v)}...")
      if !check_version_exists(v) {
        raise fail(
          "版本 \{@utils.yellow(v)} 不存在，请检查版本号是否正确（可用 mvm upgrade 升级到最新版本）",
        )
      }
      v
    }
    None =>
      // --reinstall 时直接使用当前版本，跳过"已是最新版本"检查
      if reinstall {
        @log.info("正在重新安装当前版本 \{@utils.yellow(VERSION)}...")
        VERSION
      } else {
        @log.info("正在检查最新版本...")
        let latest = fetch_latest_version()
        if latest.is_blank() {
          raise fail("无法获取最新版本信息，请检查网络连接")
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
    _ => raise fail("升级失败，请尝试手动执行安装命令")
  }
}

///|
/// 从 GitHub releases JSON 响应中提取所有 tag_name
fn extract_all_tag_names(body : String) -> Array[String] {
  let prefix = "\"tag_name\":"
  let versions : Array[String] = []
  let mut search_from = 0
  let body_len = body.length()
  while search_from < body_len {
    let remaining = body[search_from:]
    match remaining.find(prefix) {
      Some(offset) => {
        let after_prefix = body[search_from + offset + prefix.length():]
        match after_prefix.find("\"") {
          Some(q1) => {
            let content = after_prefix[q1 + 1:]
            match content.find("\"") {
              Some(q2) => {
                versions.push(content[:q2].to_owned())
                search_from = search_from +
                  offset +
                  prefix.length() +
                  q1 +
                  1 +
                  q2 +
                  1
              }
              None => break
            }
          }
          None => break
        }
      }
      None => break
    }
  }
  versions
}

///|
/// 查询所有可用的 mvm 版本
pub async fn run_upgrade_list() -> Unit {
  @log.info("正在获取所有可用的 mvm 版本...")
  let (res, data) = @http.get(
    GITHUB_API_RELEASES,
    headers=@request.merge_detault_headers(),
  )
  if res.code != 200 {
    raise fail(
      "无法获取版本列表（HTTP \{res.code}），请检查网络连接",
    )
  }
  let body = data.text()
  let versions = extract_all_tag_names(body)
  if versions.is_empty() {
    raise fail("未找到任何版本信息")
  }
  @log.info("可用的 mvm 版本（共 \{versions.length()} 个）：")
  for v in versions {
    let marker = if v == VERSION { " ← 当前版本" } else { "" }
    println("  \{@utils.yellow(v)}\{marker}")
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
