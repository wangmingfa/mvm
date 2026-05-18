///|
using @command {run, type Command}

///|
/// 导入 Tool 枚举，用于 Run 命令测试中 Tool::Node 等变体引用
using @tool_def {type Tool}

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
  assert_true(result.output.contains("mvm"))
  assert_true(result.output.contains("命令"))
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
/// ConfigList 命令：输出包含配置项关键字
async test "config list 命令返回 CommandResult" {
  let result = run(Command::ConfigList)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  assert_true(
    result.output.contains("github_proxy") || result.output.contains("registry"),
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
/// UpgradeList 命令：输出包含版本列表格式
async test "upgrade list 命令返回 CommandResult" {
  let result = run(Command::UpgradeList)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 版本列表应包含数字版本号
  assert_true(result.output.length() > 0)
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
/// CacheClean 命令：输出包含清理结果信息
async test "cache clean 命令返回 CommandResult" {
  let result = run(Command::CacheClean)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  assert_true(result.output.length() > 0)
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
/// Current 全部工具：可能成功也可能失败
async test "current 命令（全部工具）返回 CommandResult" {
  let result = run(Command::Current(None))
  if result.is_success() {
    assert_true(result.output.length() > 0)
  } else {
    // 失败来自 raise fail，error 必为 Some
    assert_true(result.error is Some(_))
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
  assert_true(result.output.length() > 0)
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
  // 输出应包含 Node 相关信息或提示无安装版本
  assert_true(result.output.length() > 0)
}

///|
/// Which 指定工具：成功时输出包含路径，失败时 error 不为 None
async test "which 命令（指定工具 Node）返回 CommandResult" {
  let result = run(Command::Which(Tool::Node))
  if result.is_success() {
    assert_true(result.output.contains("/") || result.output.contains("node"))
  } else {
    // 失败来自 raise fail，error 必为 Some
    assert_true(result.error is Some(_))
  }
}

// ========= Run 命令核心测试 =========
// 注意：Run 命令子进程非零退出时 exit_code!=0 但 error 为 None
// 所以失败时不断言 error is Some，仅在 raise fail 场景下断言

///|
/// Run node -v：验证 Node 版本输出
async test "run node -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["node", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // 版本号以 v 开头
  assert_true(result.plain_output().contains("v"))
}

///|
/// Run npm -v：验证 npm 版本输出
async test "run npm -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["npm", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  // npm 版本号是纯数字
  inspect(
    result.plain_output(),
    content=(
      #|11.12.1
    ),
  )
}

///|
/// Run npx -v：验证 npx 版本输出
async test "run npx -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "", ["npx", "-v"]))
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  inspect(
    result.plain_output(),
    content=(
      #|11.12.1
    ),
  )
}

///|
/// Run bunx -v：Bun 可能未安装，容许成功或失败
async test "run bunx -v 返回 CommandResult" {
  let result = run(Command::Run(Tool::Bun, "", ["bunx", "-v"]))
  if result.is_success() {
    assert_true(result.plain_output().length() > 0)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run rustc --version：验证 rustc 版本输出
async test "run rustc --version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Rust, "", ["rustc", "--version"]))
  if result.is_success() {
    assert_true(result.plain_output().contains("rustc"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run go version：验证 Go 版本输出
async test "run go version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Go, "", ["go", "version"]))
  if result.is_success() {
    assert_true(result.plain_output().contains("go"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run deno -V：Deno 可能未安装，容许成功或失败
async test "run deno -V 返回 CommandResult" {
  let result = run(Command::Run(Tool::Deno, "", ["deno", "-V"]))
  if result.is_success() {
    assert_true(result.plain_output().contains("deno"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run python3 -V：Python 可能未安装，容许成功或失败
async test "run python3 -V 返回 CommandResult" {
  let result = run(Command::Run(Tool::Python, "", ["python3", "-V"]))
  if result.is_success() {
    assert_true(result.plain_output().contains("Python"))
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run java -version：Java 可能未安装，容许成功或失败
async test "run java -version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Java, "", ["java", "-version"]))
  if result.is_success() {
    // java -version 输出到 stderr，stdout 可能为空
    assert_true(result.exit_code == 0)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run kotlin -version：Kotlin 可能未安装，容许成功或失败
async test "run kotlin -version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Kotlin, "", ["kotlin", "-version"]))
  if result.is_success() {
    assert_true(result.plain_output().length() > 0)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run zig version：Zig 可能未安装，容许成功或失败
async test "run zig version 返回 CommandResult" {
  let result = run(Command::Run(Tool::Zig, "", ["zig", "version"]))
  if result.is_success() {
    assert_true(result.plain_output().length() > 0)
  }
  // 失败时不做额外断言（可能来自 raise fail 或子进程非零退出）
}

///|
/// Run 不存在的程序：应返回 failure（raise fail 路径，error 必为 Some）
async test "run 不存在的程序返回 failure" {
  let result = run(Command::Run(Tool::Node, "", ["nonexistent_program_xyz"]))
  assert_true(!result.is_success())
  assert_true(result.error is Some(_))
}

///|
/// Run 空参数：应返回 failure（raise fail 路径），error 包含提示信息
async test "run 空参数返回 failure" {
  let result = run(Command::Run(Tool::Node, "", []))
  assert_true(!result.is_success())
  let msg = match result.error {
    Some(m) => m
    None => ""
  }
  assert_true(msg.contains("不能为空"))
}

///|
/// Run 指定版本号：成功时验证版本输出，失败时容许
async test "run 指定版本号 node@22 返回 CommandResult" {
  let result = run(Command::Run(Tool::Node, "22", ["node", "-v"]))
  if result.is_success() {
    assert_true(result.plain_output().contains("v"))
  }
  // 失败时不做额外断言（版本 22 可能未安装，可能来自 raise fail 或子进程非零退出）
}
