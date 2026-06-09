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
  let (res, data) = @request.github_get(url)
  if res.code != 200 {
    // 打印详细的请求失败原因，便于排查问题
    @log.debug(
      "check_version_exists failed: version=\{version}, code=\{res.code}, reason=\{res.reason}, body=\{data.text()}",
    )
    return false
  }
  true
}

///|
/// 执行 upgrade 命令，可指定目标版本；reinstall 为 true 时重新安装当前版本
async fn run_upgrade(version : String?, reinstall : Bool) -> CommandResult {
  let result = CommandResult::success()
  // 确定目标版本：指定版本需验证存在性，未指定则获取最新版本
  let target_version = match version {
    Some(v) => {
      let v = normalize_version(v)
      // 正在验证版本
      @log.info(
        @i18n.t("upgrade.verifying_version", args={
          "version": @utils.yellow(v),
        }),
      )
      if !check_version_exists(v) {
        // 版本不存在
        raise fail(
          @i18n.t("upgrade.version_not_exists", args={
            "version": @utils.yellow(v),
          }),
        )
      }
      v
    }
    None =>
      // --reinstall 时直接使用当前版本，跳过"已是最新版本"检查
      if reinstall {
        // 正在重新安装当前版本
        @log.info(
          @i18n.t("upgrade.reinstalling_current", args={
            "version": @utils.yellow(VERSION),
          }),
        )
        VERSION
      } else {
        // 正在检查最新版本
        @log.info(@i18n.t("upgrade.checking_latest"))
        let latest = fetch_latest_version()
        if latest.is_blank() {
          // 无法获取最新版本信息
          raise fail(@i18n.t("upgrade.cannot_fetch_latest"))
        }
        // 当前版本和最新版本
        @log.info(
          @i18n.t("upgrade.current_and_latest", args={
            "current": @utils.yellow(VERSION),
            "latest": @utils.yellow(latest),
          }),
        )
        if latest == VERSION {
          // 已是最新版本
          @log.success(@i18n.t("upgrade.already_latest"))
          return result
        }
        latest
      }
  }
  // 正在升级到
  @log.info(
    @i18n.t("upgrade.upgrade_target", args={
      "version": @utils.yellow(target_version),
    }),
  )
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
    0 =>
      // 升级成功
      @log.success(
        @i18n.t("upgrade.upgrade_success_msg", args={
          "version": target_version,
        }),
      )
    // 升级失败
    _ => raise fail(@i18n.t("upgrade.upgrade_failed"))
  }
  result
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
async fn run_upgrade_list() -> CommandResult {
  let result = CommandResult::success()
  // 正在获取所有可用版本
  @log.info(@i18n.t("upgrade.fetching_all_versions"))
  let (res, data) = @request.github_get(GITHUB_API_RELEASES)
  if res.code != 200 {
    // 无法获取版本列表
    raise fail(
      @i18n.t("upgrade.cannot_fetch_version_list", args={
        "code": res.code.to_string(),
        "reason": res.reason,
        "url": GITHUB_API_RELEASES,
      }),
    )
  }
  let body = data.text()
  let versions = extract_all_tag_names(body)
  if versions.is_empty() {
    // 未找到版本信息，打印响应内容便于排查
    @log.debug("run_upgrade_list: no versions found in response body: \{body}")
    raise fail(@i18n.t("upgrade.no_versions_found"))
  }
  // 可用版本列表
  @log.info(
    @i18n.t("upgrade.available_versions_count", args={
      "count": versions.length().to_string(),
    }),
  )
  for v in versions {
    // 当前版本标记
    let marker = if v == VERSION {
      " \{@i18n.t("upgrade.current_marker")}"
    } else {
      ""
    }
    print_to(result, "  \{@utils.yellow(v)}\{marker}")
  }
  result
}

///|
/// 从 GitHub API 获取最新 release 版本号
async fn fetch_latest_version() -> String {
  try {
    let (res, data) = @request.github_get(GITHUB_API_LATEST)
    if !(res.code is (200..<300)) {
      // 打印详细的请求失败原因，便于排查问题
      @log.debug(
        "fetch_latest_version failed: code=\{res.code}, reason=\{res.reason}, url=\{GITHUB_API_LATEST}, body=\{data.text()}",
      )
      return ""
    }
    let body = data.text()
    // 从 JSON 中提取 "tag_name": "vX.Y.Z"
    let prefix = "\"tag_name\":"
    guard body.find(prefix) is Some(start) else {
      @log.debug("fetch_latest_version: tag_name not found in response body")
      return ""
    }
    let after = body[start + prefix.length():]
    guard after.find("\"") is Some(q1) else {
      @log.debug("fetch_latest_version: malformed JSON - missing opening quote")
      return ""
    }
    let tag_start = after[q1 + 1:]
    guard tag_start.find("\"") is Some(q2) else {
      @log.debug("fetch_latest_version: malformed JSON - missing closing quote")
      return ""
    }
    tag_start[:q2].to_owned()
  } catch {
    err => {
      // 捕获并打印异常信息，便于排查网络或解析错误
      @log.debug("fetch_latest_version exception: \{err}")
      ""
    }
  }
}
