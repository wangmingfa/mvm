## ADDED Requirements

### Requirement: CommandResult 类型定义

`CommandResult` 是一个 struct，包含以下字段：
- `output : String` — 命令的标准输出内容（可变字段，可追加）
- `exit_code : Int` — 命令退出码，0 表示成功
- `error : String?` — 错误信息，成功时为 None

#### Scenario: 创建成功结果
- **WHEN** 调用 `CommandResult::success()`
- **THEN** 返回 `CommandResult` 且 `exit_code == 0`、`error == None`、`output == ""`

#### Scenario: 创建带输出的成功结果
- **WHEN** 调用 `CommandResult::success_with_output("v0.0.1")`
- **THEN** 返回 `CommandResult` 且 `exit_code == 0`、`error == None`、`output == "v0.0.1"`

#### Scenario: 创建失败结果（默认退出码）
- **WHEN** 调用 `CommandResult::failure("未安装")`（不传 exit_code）
- **THEN** 返回 `CommandResult` 且 `exit_code == 1`（默认值）、`error == Some("未安装")`、`output == ""`

#### Scenario: 创建失败结果（指定退出码）
- **WHEN** 调用 `CommandResult::failure("未安装", exit_code=2)`
- **THEN** 返回 `CommandResult` 且 `exit_code == 2`、`error == Some("未安装")`、`output == ""`

#### Scenario: 追加输出内容
- **WHEN** 对 `CommandResult` 实例调用 `result.write("hello\n")`
- **THEN** `output` 字段追加 `"hello\n"`，不覆盖原有内容

#### Scenario: 包装函数 print_to 同时打印并捕获
- **WHEN** 调用 `print_to(result, "hello")`
- **THEN** 控制台打印 `"hello\n"`（与原 `println` 行为一致），且 `result.output` 追加 `"hello\n"`

#### Scenario: @log 输出不捕获到 CommandResult
- **WHEN** 子命令中调用 `@log.debug/info/warn(msg)`
- **THEN** 这些日志输出保持原样不改，不写入 `CommandResult.output`（日志仅用于排查问题，不属于命令的实际结果）

#### Scenario: 判断是否成功
- **WHEN** 调用 `result.is_success()` 且 `exit_code == 0`
- **THEN** 返回 `true`
- **WHEN** 调用 `result.is_success()` 且 `exit_code != 0`
- **THEN** 返回 `false`

---

### Requirement: run 函数返回 CommandResult

`run(Command) -> Unit` 改为 `run(Command) -> CommandResult`，所有子命令处理器同样返回 `CommandResult`。

#### Scenario: 执行 Version 命令
- **WHEN** 调用 `run(Version)`
- **THEN** 返回 `CommandResult` 且 `exit_code == 0`、`output` 包含版本号字符串

#### Scenario: 执行 Help 命令
- **WHEN** 调用 `run(Help)`
- **THEN** 返回 `CommandResult` 且 `exit_code == 0`、`output` 包含帮助信息文本

#### Scenario: 执行 Run 命令成功（通过 C FFI 捕获子进程输出）
- **WHEN** 调用 `run(Run(Node, "18", ["node", "-v"]))` 且目标程序执行成功
- **THEN** 使用 C FFI `run_with_output` 执行子进程，同时流式输出到控制台并捕获 stdout；返回 `CommandResult` 且 `exit_code == 0`、`output` 仅包含子进程 stdout 的实际输出（如 `v18.x.x`），不包含中间的 `@log.debug/info` 日志信息

#### Scenario: 执行 Run 命令失败
- **WHEN** 调用 `run(Run(Node, "18", ["node", "-v"]))` 且目标程序返回非零退出码
- **THEN** 返回 `CommandResult` 且 `exit_code != 0`

#### Scenario: 子命令内部 raise fail 被捕获
- **WHEN** 子命令内部调用 `raise fail("参数错误")`
- **THEN** `run` 函数捕获该错误，返回 `CommandResult` 且 `exit_code != 0`、`error == Some("参数错误")`

---

### Requirement: 白盒测试可断言 CommandResult

测试代码可对 `CommandResult` 的字段进行逻辑断言，替代仅依赖控制台输出。

#### Scenario: 测试 version 命令输出
- **WHEN** 在测试中调用 `run(Version)` 获取 `result`
- **THEN** 可断言 `result.exit_code == 0` 且 `result.output.has_prefix("v")`

#### Scenario: 测试 help 命令包含关键文本
- **WHEN** 在测试中调用 `run(Help)` 获取 `result`
- **THEN** 可断言 `result.output.contains("mvm")` 且 `result.output.contains("命令")`

#### Scenario: 测试错误命令返回失败结果
- **WHEN** 在测试中调用 `run(Run(Node, "", []))`（空参数）
- **THEN** 可断言 `result.is_success() == false` 且 `result.error` 包含错误描述

## CHANGED Requirements

### Requirement: 子命令处理器签名变更

所有子命令处理器从返回 `Unit` 改为返回 `CommandResult`：
- `run_help() -> CommandResult`
- `run_version() -> CommandResult`
- `run_upgrade(version, reinstall) -> CommandResult`
- `run_upgrade_list() -> CommandResult`
- `run_setup(use_prefix) -> CommandResult`
- `run_install(tool, version, skip_verify, no_cache) -> CommandResult`
- `run_pin(tool, version) -> CommandResult`
- `run_use(tool, version) -> CommandResult`
- `run_unuse(tool) -> CommandResult`
- `run_list(tool_opt) -> CommandResult`
- `run_uninstall(tool, version) -> CommandResult`
- `run_which(tool) -> CommandResult`
- `run_current(tool_opt) -> CommandResult`
- `run_run(tool, version, args) -> CommandResult`
- `run_cache_clean() -> CommandResult`
- `run_config() -> CommandResult`
- `run_config_set(key, value) -> CommandResult`
- `run_config_preset(name) -> CommandResult`

---

### Requirement: C FFI 子进程输出捕获

在 `command` 包中通过 C FFI 实现 `run_with_output` 函数，解决 MoonBit `@process.run` 无法同时流式输出和捕获 stdout 的问题。

#### Scenario: C FFI run_with_output 流式输出并捕获
- **WHEN** 调用 C FFI `run_with_output(cmd, args, envs)` 执行子进程（如 `node -v`）
- **THEN** 子进程 stdout 在运行时实时流式输出到控制台（用户体验与原 `@process.run` 一致），同时 stdout 内容被捕获到返回值 `RunOutput.output`（Bytes 类型）

#### Scenario: C FFI 返回子进程退出码
- **WHEN** 子进程正常退出
- **THEN** `RunOutput.exit_code` 等于子进程的实际退出码

#### Scenario: C FFI 跨平台兼容
- **WHEN** 在 macOS/Linux 系统上运行
- **THEN** 使用 POSIX `fork/exec/pipe` 实现子进程输出捕获
- **WHEN** 在 Windows 系统上运行
- **THEN** 需使用 Windows API（`CreateProcess` + pipe）实现，或对 Windows 仍使用 `@process.run`（不捕获输出）

#### Scenario: run_run 使用 C FFI 替代 @mvm_cmd.run
- **WHEN** 改造 `run_run` 子命令
- **THEN** 用 `@mvm_cmd.run_with_output()` 替代原 `@mvm_cmd.run()`，获取子进程 stdout 输出和退出码，写入 `CommandResult.output` 和 `CommandResult.exit_code`

#### Scenario: run_version 使用包装函数替代 println
- **WHEN** 执行 `run_version()`（原实现为 `println(VERSION)`）
- **THEN** 改为使用 `print_to(result, VERSION)`，运行时仍实时打印到控制台，`result.output` 同时捕获 VERSION

#### Scenario: run_help 使用包装函数替代多个 println
- **WHEN** 执行 `run_help()`（原实现包含多个 `println`）
- **THEN** 每个原 `println(msg)` 改为 `print_to(result, msg)`，运行时仍实时打印到控制台，`result.output` 同时捕获所有输出