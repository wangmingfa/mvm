///|
/// 执行查看版本命令
pub async fn run_list(tool_opt : @lib.Tool?) -> Unit {
  match tool_opt {
    Some(tool) => {
      println("已安装的 \{tool} 版本：")
      let versions = @lib.installed_versions(tool)
      if versions.length() == 0 {
        println("  (暂无)")
      } else {
        for v in versions {
          println("  - \{v}")
        }
      }
    }
    None => {
      println("已安装的所有版本：")
      println("\nNode:")
      let node_versions = @lib.installed_versions(@lib.Node)
      if node_versions.length() == 0 {
        println("  (暂无)")
      } else {
        for v in node_versions {
          println("  - \{v}")
        }
      }
      // println("\nBun:")
      // let bun_versions = @lib.installed_versions(@lib.Bun)
      // if bun_versions.length() == 0 {
      //   println("  (暂无)")
      // } else {
      //   for v in bun_versions {
      //     println("  - \{v}")
      //   }
      // }
      println("\nZig:")
      let zig_versions = @lib.installed_versions(@lib.Zig)
      if zig_versions.length() == 0 {
        println("  (暂无)")
      } else {
        for v in zig_versions {
          println("  - \{v}")
        }
      }
    }
  }
}
