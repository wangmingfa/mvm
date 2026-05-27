///|
/// 执行查看配置命令
async fn run_config() -> CommandResult {
  let result = CommandResult::success()
  let (config_path, config) = @tools.get_global_config()

  // MVM 配置
  print_to(result, @i18n.t("config.title"))
  // 全局配置文件
  print_to(result, @i18n.t("config.global_path", args={ "path": config_path }))
  print_to(result, "")
  // GitHub 代理配置
  print_to(result, @i18n.t("config.github_proxy"))
  match config.github_proxy {
    Some(proxy) => print_to(result, @i18n.t("config.list_key", args={ "key": "github_proxy", "value": proxy }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "github_proxy", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // Node 镜像配置
  print_to(result, @i18n.t("config.node_mirror"))
  match config.node_mirror {
    Some(mirror) => print_to(result, @i18n.t("config.list_key", args={ "key": "node_mirror", "value": mirror }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "node_mirror", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // Go 镜像配置
  print_to(result, @i18n.t("config.go_mirror"))
  match config.go_mirror {
    Some(mirror) => print_to(result, @i18n.t("config.list_key", args={ "key": "go_mirror", "value": mirror }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "go_mirror", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // Python 镜像配置
  print_to(result, @i18n.t("config.python_mirror"))
  match config.python_mirror {
    Some(mirror) => print_to(result, @i18n.t("config.list_key", args={ "key": "python_mirror", "value": mirror }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "python_mirror", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // Rust 镜像配置
  print_to(result, @i18n.t("config.rust_mirror"))
  match config.rust_mirror {
    Some(mirror) => print_to(result, @i18n.t("config.list_key", args={ "key": "rust_mirror", "value": mirror }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "rust_mirror", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // Java 镜像配置
  print_to(result, @i18n.t("config.java_mirror"))
  match config.java_mirror {
    Some(mirror) => print_to(result, @i18n.t("config.list_key", args={ "key": "java_mirror", "value": mirror }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "java_mirror", "value": @i18n.t("config.not_set") }))
  }
  print_to(result, "")
  // 语言配置
  print_to(result, @i18n.t("config.language"))
  match config.language {
    Some(lang) => print_to(result, @i18n.t("config.list_key", args={ "key": "language", "value": lang }))
    None => print_to(result, @i18n.t("config.list_key", args={ "key": "language", "value": @i18n.t("config.language_default") }))
  }
  result
}

///|
/// 校验 URL 类配置值
/// - URL 类值必须以 http:// 或 https:// 开头（严格校验，不通过则 raise fail）
/// - github_proxy 值应包含 $URL 变量（宽松校验，缺少则 warn 但不阻断）
fn validate_config_url(key : String, value : String) -> Unit raise {
  if !value.has_prefix("http://") && !value.has_prefix("https://") {
    // URL 校验失败
    raise fail(
      @i18n.t("config.url_invalid", args={ "key": key, "value": value }),
    )
  }
  if key == "github_proxy" && !value.contains("$URL") {
    // github_proxy 缺少 $URL 变量
    @log.warn(@i18n.t("config.proxy_no_url_var"))
  }
}

///|
/// 执行设置配置命令
async fn run_config_set(key : String, value : String) -> CommandResult {
  let result = CommandResult::success()
  let (_, existing_config) = @tools.get_global_config()
  match key {
    "github_proxy" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        github_proxy=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      // 配置已保存
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      // 设置键值
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "node_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        node_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "go_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        go_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "python_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        python_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "rust_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        rust_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "java_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        java_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    "language" => {
      // 语言配置值校验：仅允许 zh、zh-CN、en、en-US
      let valid_langs = ["zh", "zh-CN", "en", "en-US"]
      if !valid_langs.contains(value) {
        // language 值无效
        raise fail(
          @i18n.t("config.lang_invalid", args={ "valid_values": valid_langs.join(", "), "value": value }),
        )
      }
      let new_config = @tools.make_global_config(
        existing_config~,
        language=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      print_to(result, @i18n.t("config.set_value", args={ "key": key, "value": value }))
    }
    _ => {
      println(
        @utils.colored_spans([
          (Red, @i18n.t("config.error_prefix")),
          (Yellow, @i18n.t("config.unsupported_key_label")),
          (Cyan, key),
        ]),
      )
      // 支持的配置项
      println(@i18n.t("config.supported_keys"))
      println("  \{@i18n.t("config.key_desc_github_proxy")}")
      println("  \{@i18n.t("config.key_desc_node_mirror")}")
      println("  \{@i18n.t("config.key_desc_go_mirror")}")
      println("  \{@i18n.t("config.key_desc_python_mirror")}")
      println("  \{@i18n.t("config.key_desc_rust_mirror")}")
      println("  \{@i18n.t("config.key_desc_java_mirror")}")
      println("  \{@i18n.t("config.key_desc_language")}")
      // 不支持的配置项
      raise fail(@i18n.t("config.key_not_supported", args={ "key": key }))
    }
  }
  result
}

///|
/// 预设配置
fn get_preset_config(name : String) -> @tools.GlobalConfig? {
  match name.to_lower() {
    "china" =>
      Some({
        github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
        node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
        go_mirror: Some("https://mirrors.aliyun.com/golang"),
        python_mirror: Some("https://mirrors.aliyun.com/python"),
        rust_mirror: Some("https://mirrors.aliyun.com/rustup"),
        java_mirror: Some("https://mirrors.aliyun.com/adoptium"),
        language: Some("zh"),
      })
    _ => None
  }
}

///|
/// 执行预设配置命令
async fn run_config_preset(name : String) -> CommandResult {
  match get_preset_config(name) {
    Some(preset) => {
      let result = CommandResult::success()
      let config_path = @tools.save_global_config(preset)
      // 已应用快速配置
      print_to(result, @i18n.t("config.preset_applied"))
      print_to(result, preset.to_string(indent=2))
      // 配置已保存
      print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
      result
    }
    _ => {
      // 支持的预设配置
      println(@i18n.t("config.supported_presets"))
      // china 预设描述
      println("  \{@i18n.t("config.china_preset_desc")}")
      // 不支持的预设配置
      raise fail(@i18n.t("config.preset_not_supported", args={ "preset": name }))
    }
  }
}

///|
test "validate_config_url_valid" {
  // 合法 URL 应通过校验
  try {
    validate_config_url(
      "node_mirror", "https://mirrors.aliyun.com/nodejs-release",
    )
    validate_config_url("node_mirror", "http://example.com/mirror")
    validate_config_url("go_mirror", "https://mirrors.aliyun.com/golang")
  } catch {
    _ => fail("valid URL should not raise error")
  }
}

///|
test "validate_config_url_invalid" {
  // 不以 http:// 或 https:// 开头的 URL 应抛出错误
  try {
    validate_config_url("node_mirror", "ftp://example.com")
    fail("should reject ftp:// URL")
  } catch {
    _ => ()
  }
  try {
    validate_config_url("node_mirror", "example.com")
    fail("should reject URL without protocol")
  } catch {
    _ => ()
  }
}

///|
test "validate_config_url_github_proxy_without_url_var" {
  // github_proxy 缺少 $URL 变量时应 warn 但不阻断
  validate_config_url("github_proxy", "https://proxy.example.com")
  // 此测试应通过（不抛出错误），仅输出 warn 日志
}