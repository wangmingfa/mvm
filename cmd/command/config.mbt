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
}

///|
/// 执行设置配置命令
pub async fn run_config_set(key : String, value : String) -> Unit {
  match key {
    "github_proxy" => {
      let new_config = @tools.make_global_config(Some(value))
      let config_path = @tools.save_global_config(new_config)
      println("配置已保存到: \{config_path}")
      println("设置 \{key} = \{value}")
    }
    _ => {
      println("错误: 不支持的配置项: \{key}")
      println("支持的配置项:")
      println("  github_proxy - GitHub 代理地址")
    }
  }
}
