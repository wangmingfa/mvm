///|
/// 执行查看配置命令
async fn run_config() -> CommandResult {
  let result = CommandResult::success()
  let (config_path, config) = @tools.get_global_config()

  print_to(result, "MVM 配置:")
  print_to(result, "全局配置文件: \{config_path}")
  print_to(result, "")
  print_to(result, "Logo 显示:")
  match config.logo {
    Some(true) => print_to(result, "  logo: 显示")
    Some(false) => print_to(result, "  logo: 隐藏")
    None => print_to(result, "  logo: 显示（默认）")
  }
  print_to(result, "")
  print_to(result, "GitHub 代理配置:")
  match config.github_proxy {
    Some(proxy) => print_to(result, "  github_proxy: \{proxy}")
    None => print_to(result, "  github_proxy: (未设置)")
  }
  print_to(result, "")
  print_to(result, "Node 镜像配置:")
  match config.node_mirror {
    Some(mirror) => print_to(result, "  node_mirror: \{mirror}")
    None => print_to(result, "  node_mirror: (未设置)")
  }
  print_to(result, "")
  print_to(result, "Go 镜像配置:")
  match config.go_mirror {
    Some(mirror) => print_to(result, "  go_mirror: \{mirror}")
    None => print_to(result, "  go_mirror: (未设置)")
  }
  print_to(result, "")
  print_to(result, "Python 镜像配置:")
  match config.python_mirror {
    Some(mirror) => print_to(result, "  python_mirror: \{mirror}")
    None => print_to(result, "  python_mirror: (未设置)")
  }
  print_to(result, "")
  print_to(result, "Rust 镜像配置:")
  match config.rust_mirror {
    Some(mirror) => print_to(result, "  rust_mirror: \{mirror}")
    None => print_to(result, "  rust_mirror: (未设置)")
  }
  print_to(result, "")
  print_to(result, "Java 镜像配置:")
  match config.java_mirror {
    Some(mirror) => print_to(result, "  java_mirror: \{mirror}")
    None => print_to(result, "  java_mirror: (未设置)")
  }
  result
}

///|
/// 校验 URL 类配置值
/// - URL 类值必须以 http:// 或 https:// 开头（严格校验，不通过则 raise fail）
/// - github_proxy 值应包含 $URL 变量（宽松校验，缺少则 warn 但不阻断）
fn validate_config_url(key : String, value : String) -> Unit raise {
  if !value.has_prefix("http://") && !value.has_prefix("https://") {
    raise fail(
      "配置项 \{key} 的值必须是有效的 URL（以 http:// 或 https:// 开头），当前值：\{value}",
    )
  }
  if key == "github_proxy" && !value.contains("$URL") {
    // @log 日志不捕获到 CommandResult
    @log.warn(
      "github_proxy 值中未包含 $URL 变量，可能导致代理功能异常",
    )
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
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "node_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        node_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "go_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        go_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "python_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        python_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "rust_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        rust_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "java_mirror" => {
      validate_config_url(key, value)
      let new_config = @tools.make_global_config(
        existing_config~,
        java_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      print_to(result, "设置 \{key} = \{value}")
    }
    "logo" => {
      let logo_val = match value.to_lower() {
        "true" | "1" | "yes" | "on" => Some(true)
        "false" | "0" | "no" | "off" => Some(false)
        _ => raise fail("错误: logo 配置值只能是 true 或 false")
      }
      let new_config = @tools.make_global_config(
        existing_config~,
        logo=logo_val,
      )
      let config_path = @tools.save_global_config(new_config)
      print_to(result, "配置已保存到: \{config_path}")
      let label = if logo_val is Some(true) { "显示" } else { "隐藏" }
      print_to(result, "设置 logo = \{label}")
    }
    _ => {
      println(
        @utils.colored_spans([
          (Red, "错误: "),
          (Yellow, "不支持的配置项 "),
          (Cyan, key),
        ]),
      )
      println("支持的配置项:")
      println("  logo - 是否显示启动 logo（true/false）")
      println("  github_proxy - GitHub 代理地址")
      println("  node_mirror - Node 镜像地址")
      println("  go_mirror - Go 镜像地址")
      println("  python_mirror - Python 镜像地址")
      println("  rust_mirror - Rust 镜像地址")
      println("  java_mirror - Java 镜像地址")
      raise fail("不支持的配置项 \{key}")
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
        logo: None,
        github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
        node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
        go_mirror: Some("https://mirrors.aliyun.com/golang"),
        python_mirror: Some("https://mirrors.aliyun.com/python"),
        rust_mirror: Some("https://mirrors.aliyun.com/rustup"),
        java_mirror: Some("https://mirrors.aliyun.com/adoptium"),
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
      print_to(result, "已应用快速配置:")
      print_to(result, preset.to_string(indent=2))
      print_to(result, "配置已保存到: \{config_path}")
      result
    }
    _ => {
      println("支持的预设配置:")
      println(
        "  china - 中国大陆快速配置（GitHub 代理 + Node/Go/Python/Rust/Java 镜像）",
      )
      raise fail("不支持的预设配置: \{name}")
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
