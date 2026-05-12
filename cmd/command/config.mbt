///|
/// 执行查看配置命令
pub async fn run_config() -> Unit {
  let (config_path, config) = @tools.get_global_config()

  println("MVM 配置:")
  println("全局配置文件: \{config_path}")
  println("")
  println("GitHub 代理配置:")
  match config.github_proxy {
    Some(proxy) => println("  github_proxy: \{proxy}")
    None => println("  github_proxy: (未设置)")
  }
  println("")
  println("Node 镜像配置:")
  match config.node_mirror {
    Some(mirror) => println("  node_mirror: \{mirror}")
    None => println("  node_mirror: (未设置)")
  }
  println("")
  println("Go 镜像配置:")
  match config.go_mirror {
    Some(mirror) => println("  go_mirror: \{mirror}")
    None => println("  go_mirror: (未设置)")
  }
}

///|
/// 执行设置配置命令
pub async fn run_config_set(key : String, value : String) -> Unit {
  let (_, existing_config) = @tools.get_global_config()
  match key {
    "github_proxy" => {
      let new_config = @tools.make_global_config(
        existing_config~,
        github_proxy=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      println("配置已保存到: \{config_path}")
      println("设置 \{key} = \{value}")
    }
    "node_mirror" => {
      let new_config = @tools.make_global_config(
        existing_config~,
        node_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      println("配置已保存到: \{config_path}")
      println("设置 \{key} = \{value}")
    }
    "go_mirror" => {
      let new_config = @tools.make_global_config(
        existing_config~,
        go_mirror=Some(value),
      )
      let config_path = @tools.save_global_config(new_config)
      println("配置已保存到: \{config_path}")
      println("设置 \{key} = \{value}")
    }
    _ => {
      println("错误: 不支持的配置项: \{key}")
      println("支持的配置项:")
      println("  github_proxy - GitHub 代理地址")
      println("  node_mirror - Node 镜像地址")
      println("  go_mirror - Go 镜像地址")
    }
  }
}

///|
fn get_preset_config(name : String) -> @tools.GlobalConfig? {
  match name.to_lower() {
    "china" =>
      Some({
        github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
        node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
        go_mirror: None,
      })
    _ => {
      println("错误: 不支持的预设配置: \{name}")
      println("支持的预设配置:")
      println(
        "  china - 中国大陆快速配置（GitHub 代理 + Node 镜像 + Go 镜像）",
      )
      None
    }
  }
}

///|
/// 执行预设配置命令
pub async fn run_config_preset(name : String) -> Unit {
  match get_preset_config(name) {
    Some(preset) => {
      let config_path = @tools.save_global_config(preset)
      println("已应用快速配置:")
      println(preset.to_string(indent=2))
      println("配置已保存到: \{config_path}")
    }
    _ => {
      println("错误: 不支持的预设配置: \{name}")
      println("支持的预设配置:")
      println(
        "  china - 中国大陆快速配置（GitHub 代理 + Node 镜像 + Go 镜像）",
      )
    }
  }
}