## 1. 定义 CommandResult 类型

- [x] 1.1 新建 `cmd/command/result.mbt`，定义 `CommandResult` struct（`output: String`, `exit_code: Int`, `error: String?`），`output` 为 `mut` 字段
- [x] 1.2 实现 `CommandResult` 便捷构造方法：`success()`、`success_with_output(msg)`、`failure(msg: String, exit_code?: Int=1)`
- [x] 1.3 实现 `CommandResult::write(msg)` 方法，向 `output` 追加文本
- [x] 1.4 实现 `CommandResult::is_success() -> Bool` 方法
- [x] 1.5 实现输出包装函数 `print_to(result, msg)`：同时 `println(msg)` + `result.output` 追加 `msg + "\n"`（MoonBit 无 `print` 不换行函数，无需 `write_to`）
- [x] 1.6 编写 `CommandResult` 及包装函数的单元测试，验证构造方法、write、is_success、print_to 等行为

## 2. 改造 run 调度层

- [x] 2.1 修改 `run.mbt` 中 `run(Command) -> Unit` 签名为 `run(Command) -> CommandResult`
- [x] 2.2 在 `run` 函数中用 `catch` 捕获子命令的 `raise fail()`，转为 `CommandResult::failure`
- [x] 2.3 修改 `should_print_logo` 返回值处理，logo 仅打印到控制台（不捕获到 CommandResult.output，logo 是品牌标识不属于命令结果）
- [x] 2.4 更新 `pkg.generated.mbti` 中 `run` 的签名和 `CommandResult` 类型导出

## 3. 实现 C FFI run_with_output

> **背景**：MoonBit `@process.run` 只能流式输出无法捕获 stdout，`collect_output_merged` 只能捕获无法流式输出。通过 C FFI 实现 `run_with_output`，同时流式输出到控制台并捕获子进程 stdout。

- [x] 3.1 新建 `command/run_capture.c`，实现 `mvm_run_with_output` C 函数：使用 POSIX `fork/execvp/pipe` 执行子进程，从 pipe 读取 stdout 数据，同时 `write(STDOUT_FILENO)` 流式输出到控制台并写入缓冲区捕获；子进程结束后返回 `RunOutput {exit_code, output_bytes}`
- [x] 3.2 新建 `command/ffi.mbt`，声明 MoonBit FFI 类型和函数：`struct RunOutput { exit_code: Int, output: String }`，`extern "c" fn mvm_run_with_output(args_packed: Bytes, envs_packed: Bytes) -> Bytes`，辅助函数 `pack_args/pack_envs/unpack_run_result`
- [x] 3.3 修改 `command/moon.pkg`，添加 `"native-stub": ["run_capture.c"]`、`targets: {"ffi.mbt": ["native"]}` 配置及 `moonbitlang/core/encoding/utf8`、`username/mvm/ffi` 导入
- [x] 3.4 在 `command/ffi.mbt` 中新增 `pub fn run_with_output(cmd, args, extra_env?) -> RunOutput` 包装方法（native-only），调用 C FFI `mvm_run_with_output`，使用 `pack_args/pack_envs/unpack_run_result` 处理参数和结果
- [x] 3.5 编写 C FFI 集成测试：验证 `echo hello` 输出捕获、`echo hello world` 多参数、`false` 命令非零退出码、`pack_args/pack_envs/unpack_run_result` 格式

## 4. 改造简单子命令（验证模式）

- [x] 4.1 改造 `version.mbt`：`run_version() -> CommandResult`，用 `print_to(result, VERSION)` 替代 `println(VERSION)`
- [x] 4.2 改造 `help.mbt`：`run_help() -> CommandResult`，将所有 `println(msg)` 改为 `print_to(result, msg)`
- [x] 4.3 在 `mvm_wbtest.mbt` 中编写 `Version` 和 `Help` 命令的断言测试，验证 `exit_code`、`output` 内容

## 5. 改造其余子命令

> **原则**：只有 `println` 输出（命令的实际结果）需要改为 `print_to` 并捕获到 `CommandResult.output`；`@log.debug/info/warn` 日志输出保持原样不改，不放入 `CommandResult.output`。

- [x] 5.1 改造 `install.mbt`：`run_install() -> CommandResult`（`@log` 日志不改，只改 `println` 输出）
- [x] 5.2 改造 `pin.mbt`：`run_pin() -> CommandResult`
- [x] 5.3 改造 `use.mbt`：`run_use() -> CommandResult`
- [x] 5.4 改造 `unuse.mbt`：`run_unuse() -> CommandResult`
- [x] 5.5 改造 `list.mbt`：`run_list() -> CommandResult`
- [x] 5.6 改造 `uninstall.mbt`：`run_uninstall() -> CommandResult`
- [x] 5.7 改造 `which.mbt`：`run_which() -> CommandResult`
- [x] 5.8 改造 `current.mbt`：`run_current() -> CommandResult`
- [x] 5.9 改造 `run_run.mbt`：`run_run() -> CommandResult`，使用 C FFI `@mvm_cmd.run_with_output()` 替代原 `@mvm_cmd.run()`，获取子进程 stdout 输出和退出码写入 `CommandResult`（中间 `@log` 日志不捕获）；`raise fail()` 改为 `return CommandResult::failure()`，`run.mbt` 分发去掉临时包装
- [x] 5.10 改造 `cache_clean.mbt`：`run_cache_clean() -> CommandResult`
- [x] 5.11 改造 `config.mbt`：`run_config()`、`run_config_set()`、`run_config_preset() -> CommandResult`
- [x] 5.12 改造 `setup.mbt`：`run_setup() -> CommandResult`
- [x] 5.13 改造 `upgrade.mbt`：`run_upgrade()`、`run_upgrade_list() -> CommandResult`

## 6. 适配主入口

- [x] 6.1 找到主入口文件 `cmd/main/main.mbt`，将 `run(cmd)` 后的逻辑改为：处理 `result.error`（如有则打印到 stderr）、设置进程退出码为 `result.exit_code`（无需重新打印 `result.output`）
- [x] 6.2 确保 logo 打印仍正常工作（logo 仅打印到控制台，不捕获到 CommandResult.output，已通过 `@utils.print_logo()` 实现）

## 7. 编写白盒测试

- [x] 7.1 在 `mvm_wbtest.mbt` 中编写 `run(Version)` 测试：断言 `exit_code == 0` 且 `output` 包含版本号
- [x] 7.2 编写 `run(Help)` 测试：断言 `output` 包含关键文本（"mvm"、"命令"等）
- [ ] 7.3 编写 `run(Run(Node, "", ["node", "-v"]))` 测试：断言 `exit_code == 0` 且 `output` 仅包含 C FFI 捕获的子进程 stdout 结果（如 `v18.x.x`），不含 `@log` 日志信息（依赖系统环境，暂不实现）
- [x] 7.4 编写错误场景测试：`run_run(Node, "", [])` 空参数返回 `is_success() == false`，`exit_code != 0`，`error is Some(_)`
