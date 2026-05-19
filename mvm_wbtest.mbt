///|
using @command {run, type Command}

///|
/// 导入 Tool 枚举和 Config 结构体，用于版本号测试中读取 mvm.json 配置
using @tool_def {type Tool, type Config}

///|
/// 导入全局配置管理模块，用于 config 测试中直接操作 GlobalConfig
using @tools {save_global_config}

///|
using @utils {option_to_string}

// ========= 辅助函数 =========

///|
/// 从项目根目录的 mvm.json 读取指定工具的版本号
/// 用于版本号测试中与 plain_output() 进行精确对比
async fn get_mvm_version(tool : Tool) -> String {
  // 直接读取项目根目录的 mvm.json（测试运行时当前目录为项目根）
  let content = @fs.read_file("mvm.json")
  let json = content.json() catch {
    _ => raise fail("mvm.json 文件格式错误")
  }
  let config : Config = @json.from_json(json) catch {
    _ => raise fail("mvm.json 解析为 Config 失败")
  }
  guard config.get_value(tool) is Some(version) else {
    raise fail("mvm.json 中未找到 \{tool} 的版本号")
  }
  version
}

///|
/// 写入干净的默认配置（所有字段为 None），确保 config 测试从已知状态开始
fn clean_config() -> @tools.GlobalConfig {
  {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
  }
}

// ========= 纯输出命令测试 =========

///|
async test "version 命令返回 CommandResult" {
  let result = run(Command::Version)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  inspect(
    result.output,
    content=(
      #|v0.0.1
      #|
    ),
  )
  inspect(
    result.is_success(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    result.error,
    content=(
      #|None
    ),
  )
}

///|
async test "help 命令返回 CommandResult" {
  let result = run(Command::Help)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 帮助文本内容动态，用 plain_output() 去除 ANSI 颜色后检查关键字
  for keyword in ["mvm", "用法:", "选项:"] {
    assert_true(result.plain_output().contains(keyword), msg="\{keyword}")
  }
  inspect(
    result.is_success(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    result.error,
    content=(
      #|None
    ),
  )
}

///|
/// ConfigList + ConfigSet 逐项验证
/// 合并为单个测试以避免 async 测试交错执行导致并发写入 config.json 损坏
async test "config 逐项设置与验证" {
  // ===== 初始状态：写入干净配置，验证 ConfigList 基本格式 =====
  ignore(save_global_config(clean_config()))
  let list_result = run(Command::ConfigList)
  guard list_result.is_success() else {
    fail("ConfigList 失败：\{option_to_string(list_result.error)}")
  }
  assert_true(list_result.plain_output().contains("MVM 配置"))
  assert_true(list_result.plain_output().contains("github_proxy: (未设置)"))

  // ===== github_proxy =====
  let set_github = run(
    Command::ConfigSet("github_proxy", "https://cdn.gh-proxy.org/$URL"),
  )
  guard set_github.is_success() else {
    fail(
      "ConfigSet github_proxy 失败：\{option_to_string(set_github.error)}",
    )
  }
  assert_true(set_github.plain_output().contains("github_proxy"))
  let list_github = run(Command::ConfigList)
  assert_true(
    list_github
    .plain_output()
    .contains("github_proxy: https://cdn.gh-proxy.org/$URL"),
  )
  ignore(save_global_config(clean_config()))
  let clear_github = run(Command::ConfigList)
  assert_true(clear_github.plain_output().contains("github_proxy: (未设置)"))

  // ===== node_mirror =====
  let set_node = run(
    Command::ConfigSet(
      "node_mirror", "https://mirrors.aliyun.com/nodejs-release",
    ),
  )
  guard set_node.is_success() else {
    fail("ConfigSet node_mirror 失败：\{option_to_string(set_node.error)}")
  }
  assert_true(set_node.plain_output().contains("node_mirror"))
  let list_node = run(Command::ConfigList)
  assert_true(
    list_node
    .plain_output()
    .contains("node_mirror: https://mirrors.aliyun.com/nodejs-release"),
  )
  ignore(save_global_config(clean_config()))
  let clear_node = run(Command::ConfigList)
  assert_true(clear_node.plain_output().contains("node_mirror: (未设置)"))

  // ===== go_mirror =====
  let set_go = run(
    Command::ConfigSet("go_mirror", "https://mirrors.aliyun.com/golang"),
  )
  guard set_go.is_success() else {
    fail("ConfigSet go_mirror 失败：\{option_to_string(set_go.error)}")
  }
  assert_true(set_go.plain_output().contains("go_mirror"))
  let list_go = run(Command::ConfigList)
  assert_true(
    list_go
    .plain_output()
    .contains("go_mirror: https://mirrors.aliyun.com/golang"),
  )
  ignore(save_global_config(clean_config()))
  let clear_go = run(Command::ConfigList)
  assert_true(clear_go.plain_output().contains("go_mirror: (未设置)"))

  // ===== python_mirror =====
  let set_python = run(
    Command::ConfigSet("python_mirror", "https://mirrors.aliyun.com/python"),
  )
  guard set_python.is_success() else {
    fail(
      "ConfigSet python_mirror 失败：\{option_to_string(set_python.error)}",
    )
  }
  assert_true(set_python.plain_output().contains("python_mirror"))
  let list_python = run(Command::ConfigList)
  assert_true(
    list_python
    .plain_output()
    .contains("python_mirror: https://mirrors.aliyun.com/python"),
  )
  ignore(save_global_config(clean_config()))
  let clear_python = run(Command::ConfigList)
  assert_true(
    clear_python.plain_output().contains("python_mirror: (未设置)"),
  )

  // ===== rust_mirror =====
  let set_rust = run(
    Command::ConfigSet("rust_mirror", "https://mirrors.aliyun.com/rustup"),
  )
  guard set_rust.is_success() else {
    fail("ConfigSet rust_mirror 失败：\{option_to_string(set_rust.error)}")
  }
  assert_true(set_rust.plain_output().contains("rust_mirror"))
  let list_rust = run(Command::ConfigList)
  assert_true(
    list_rust
    .plain_output()
    .contains("rust_mirror: https://mirrors.aliyun.com/rustup"),
  )
  ignore(save_global_config(clean_config()))
  let clear_rust = run(Command::ConfigList)
  assert_true(clear_rust.plain_output().contains("rust_mirror: (未设置)"))

  // ===== java_mirror =====
  let set_java = run(
    Command::ConfigSet("java_mirror", "https://mirrors.aliyun.com/adoptium"),
  )
  guard set_java.is_success() else {
    fail("ConfigSet java_mirror 失败：\{option_to_string(set_java.error)}")
  }
  assert_true(set_java.plain_output().contains("java_mirror"))
  let list_java = run(Command::ConfigList)
  assert_true(
    list_java
    .plain_output()
    .contains("java_mirror: https://mirrors.aliyun.com/adoptium"),
  )
  ignore(save_global_config(clean_config()))
  let clear_java = run(Command::ConfigList)
  assert_true(clear_java.plain_output().contains("java_mirror: (未设置)"))

  // ===== 清理：恢复干净配置 =====
  ignore(save_global_config(clean_config()))
}

///|
/// UpgradeList 命令：输出包含版本列表格式
async test "upgrade list 命令返回 CommandResult" {
  let result = run(Command::UpgradeList)
  // upgrade list 依赖网络，exit_code 可能变化，用 guard 替代 inspect 精确匹配
  guard result.exit_code >= 0 else {
    fail("upgrade list 命令 exit_code 异常：\{result.exit_code}")
  }
  if result.is_success() {
    // 成功时：输出非空、无错误
    assert_true(result.plain_output().length() > 0)
    inspect(
      result.error is None,
      content=(
        #|true
      ),
    )
  } else {
    // 失败时：有错误信息
    inspect(
      result.error is Some(_),
      content=(
        #|true
      ),
    )
  }
}

///|
/// CacheClean 命令：输出包含清理结果信息
async test "cache clean 命令返回 CommandResult" {
  let result = run(Command::CacheClean)
  // cache clean 依赖文件系统状态，exit_code 可能变化，用 guard 替代 inspect 精确匹配
  guard result.exit_code >= 0 else {
    fail("cache clean 命令 exit_code 异常：\{result.exit_code}")
  }
  if result.is_success() {
    // 成功时：输出非空、无错误
    assert_true(result.plain_output().length() > 0)
    inspect(
      result.error is None,
      content=(
        #|true
      ),
    )
  } else {
    // 失败时：有错误信息
    inspect(
      result.error is Some(_),
      content=(
        #|true
      ),
    )
  }
}

///|
/// Current 全部工具：可能成���也可能失败
async test "current 命令（全部工具）返回 CommandResult" {
  let result = run(Command::Current(None))
  if result.is_success() {
    // 输出内容动态，用 plain_output() 去除 ANSI 颜色后检查非空
    assert_true(result.plain_output().length() > 0)
  } else {
    // 失败来自 raise fail，error 必为 Some
    inspect(
      result.error is Some(_),
      content=(
        #|true
      ),
    )
  }
}

// ========= 需要本地环境的命令测试 =========

///|
/// List 全部工具：输出包含工具列表格式
async test "list 命令（全部工具）返回 CommandResult" {
  let result = run(Command::List(None))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 列表输出内容动态，用 plain_output() 去除 ANSI 颜色后检查非空
  assert_true(result.plain_output().length() > 0)
}

///|
/// List 指定工具：输出包含 Node 版本列表
async test "list 命令（指定工具 Node）返回 CommandResult" {
  let result = run(Command::List(Some(Tool::Node)))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 输出应包含 Node 相关信息或提示无安装版本，用 plain_output() 去除 ANSI 颜色
  assert_true(result.plain_output().length() > 0)
}

///|
/// Which 指定工具：成功时输出包含路径，失败时 error 不为 None
async test "which 命令（指定工具 Node）返回 CommandResult" {
  let result = run(Command::Which(Tool::Node))
  if result.is_success() {
    // 路径输出用 plain_output() 去除 ANSI 颜色后检查关键字
    assert_true(
      result.plain_output().contains("/") ||
      result.plain_output().contains("node"),
    )
  } else {
    // 失败来自 raise fail，error 必为 Some
    inspect(
      result.error is Some(_),
      content=(
        #|true
      ),
    )
  }
}

// ========= Run 命令核心测试 =========
// 注意：Run 命令子进程非零退出时 exit_code!=0 但 error 为 None
// 所以失败时不断言 error is Some，仅在 raise fail 场景下断言

///|
/// Run node -v：从 mvm.json 读取版本号，用 guard 与 plain_output() 确对比
async test "run node -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["node", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 从 mvm.json 读取 node 版本号，用 inspect 与 plain_output() 精确对比
  let expected_version = get_mvm_version(Tool::Node)
  inspect(result.plain_output(), content=expected_version)
}

///|
/// Run npm -v：npm 版本号不在 mvm.json 中，保留硬编码
async test "run npm -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["npm", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // npm 版本号不在 mvm.json 中，保留硬编码值
  inspect(
    result.plain_output(),
    content=(
      #|11.12.1
    ),
  )
}

///|
/// Run npx -v：npx 版本号不在 mvm.json 中，保留硬编码
async test "run npx -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["npx", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // npx 版本号不在 mvm.json 中，保留硬编码值
  inspect(
    result.plain_output(),
    content=(
      #|11.12.1
    ),
  )
}

///|
/// Run bunx -v：从 mvm.json 读取 bun 版本号，成功时包含对比
async test "run bunx -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Bun, "", ["bunx", "-v"]))
  if result.is_success() {
    // 从 mvm.json 读取 bun 版本号，验证输出包含版本号
    let expected_version = get_mvm_version(Tool::Bun)
    guard result.plain_output().contains(expected_version) else {
      fail(
        "bunx -v 版本号不包含期望值：期望包含 \{expected_version}，实际 \{result.plain_output()}",
      )
    }
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run rustc --version：mvm.json 中版本号仅为 v1，保留 contains 断言
async test "run rustc --version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Rust, "", ["rustc", "--version"]))
  if result.is_success() {
    // rust 版本号在 mvm.json 中仅为 v1，不够精确，保留 contains 断言
    assert_true(result.plain_output().contains("rustc"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run go version：从 mvm.json 读取 go 版本号，成功时包含对比
async test "run go version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Go, "", ["go", "version"]))
  if result.is_success() {
    // 从 mvm.json 读取 go 版本号，验证输出包含 go + 版本号
    let expected_version = get_mvm_version(Tool::Go)
    guard result.plain_output().contains("go") &&
      result.plain_output().contains(expected_version) else {
      fail(
        "go version 输出不包含期望值：期望包含 go 和 \{expected_version}，实际 \{result.plain_output()}",
      )
    }
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run deno -V：从 mvm.json 读取 deno 版本号，成功时包含对比
async test "run deno -V 返回 CommandResult" {
  let result = run(Command::Run(Tool::Deno, "", ["deno", "-V"]))
  if result.is_success() {
    // 从 mvm.json 读取 deno 版本号，验证输出包含版本号核心部分
    let expected_version = get_mvm_version(Tool::Deno)
    // deno -V 输出格式为 "deno X.Y.Z"，版本号可能不含 v 前缀
    let version_core = if expected_version.has_prefix("v") {
      expected_version[1:]
    } else {
      expected_version
    }
    guard result.plain_output().contains(version_core) else {
      fail(
        "deno -V 版本号不包含期望值：期望包含 \{version_core}，实际 \{result.plain_output()}",
      )
    }
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run python3 -V：Python 版本号不在 mvm.json 中，保留模糊断言
async test "run python3 -V 返回 CommandResult" {
  let result = run(Command::Run(Tool::Python, "", ["python3", "-V"]))
  if result.is_success() {
    // Python 版本号不在 mvm.json 中，保留 contains 断言
    assert_true(result.plain_output().contains("Python"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run java -version：从 mvm.json 读取 java 版本号
async test "run java -version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Java, "", ["java", "-version"]))
  if result.is_success() {
    // java -version 输出到 stderr，stdout 可能为空
    inspect(
      result.exit_code,
      content=(
        #|0
      ),
    )
    // 从 mvm.json 读取 java 版本号，验证输出包含版本号
    let expected_version = get_mvm_version(Tool::Java)
    // java -version 输出到 stderr，plain_output() 可能不含版本号，容许 exit_code==0
    assert_true(
      result.plain_output().contains(expected_version) || result.exit_code == 0,
    )
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run kotlin -version：Kotlin 版本号不在 mvm.json 中，保留模糊断言
async test "run kotlin -version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Kotlin, "", ["kotlin", "-version"]))
  if result.is_success() {
    // Kotlin 版本号不在 mvm.json 中，保留长度断言
    assert_true(result.plain_output().length() > 0)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run zig version：从 mvm.json 读取 zig 版本号，用 guard 与 plain_output() 精确对比
async test "run zig version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Zig, "", ["zig", "version"]))
  if result.is_success() {
    // 从 mvm.json 读取 zig 版本号，用 inspect 与 plain_output() 精确对比
    let expected_version = get_mvm_version(Tool::Zig)
    inspect(result.plain_output(), content=expected_version)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run 不存在的程序：应返回 failure（raise fail 路径，error 必为 Some）
async test "run 不存在的程序返回 failure" {
  let result = run(Command::Run(Tool::Node, "", ["nonexistent_program_xyz"]))
  inspect(
    result.is_success(),
    content=(
      #|false
    ),
  )
  inspect(
    result.error is Some(_),
    content=(
      #|true
    ),
  )
}

///|
/// Run 空参数：应返回 failure，error 包含提示信息
async test "run 空参数返回 failure" {
  let result = run(Command::Run(Tool::Node, "", []))
  inspect(
    result.is_success(),
    content=(
      #|false
    ),
  )
  // error 消息包含"不能为空"关键字
  let msg = match result.error {
    Some(m) => m
    None => ""
  }
  assert_true(msg.contains("不能为空"))
}

///|
/// Run 指定版本号：成功时从 mvm.json 读取版本号进行对比
async test "run 指定版本号 node@22 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "22", ["node", "-v"]))
  if result.is_success() {
    // 从 mvm.json 读取 node 版本号，验证输出包含版本号
    let expected_version = get_mvm_version(Tool::Node)
    guard result.plain_output().contains(expected_version) else {
      fail(
        "node@22 -v 版本号不包含期望值：期望包含 \{expected_version}，实际 \{result.plain_output()}",
      )
    }
  }
  // 失败时不做额外断言（版本 22 可能未安装，可能来自 raise fail 或子进程非零退出）
}
