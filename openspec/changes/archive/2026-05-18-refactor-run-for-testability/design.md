## Context

当前 `cmd/command` 包的命令执行架构采用「直接打印」模式：
- `run(Command) -> Unit` 作为唯一公开入口，根据 `Command` 枚举分派到各子命令
- 子命令处理器（如 `run_help()`、`run_version()` 等）均返回 `Unit`
- 输出通过 `println()` 或 `@log.info()` 直接写入控制台
- 错误通过 `raise fail()` 报错，成功则静默返回 `Unit`

这种架构下白盒测试只能调用函数，无法对执行结果做逻辑断言。

## Goals / Non-Goals

**Goals:**
- 引入 `CommandResult` 类型，使命令执行结果可被程序化捕获和断言
- 重构 `run` 及所有子命令处理器，返回 `CommandResult` 替代 `Unit`
- 保持终端用户体验不变（最终仍打印到控制台）
- 让 `mvm_wbtest.mbt` 可以通过 `CommandResult` 字段进行断言

**Non-Goals:**
- 不改变 `get_command` 的命令解析逻辑（该部分已有完善的测试）
- 不引入复杂的日志框架或 I/O 抽象层
- 不改变 `raise fail()` 的错误处理机制（保持与现有代码风格一致）

## Architecture

### CommandResult 类型定义

```moonbit
/// 命令执行结果
pub(all) struct CommandResult {
  /// 标准输出内容（多条输出合并）
  mut output : String
  /// 退出码（0 表示成功）
  exit_code : Int
  /// 错误信息（如有）
  error : String?
}
```

提供便捷方法：
- `CommandResult::success()` — 创建成功结果（exit_code=0, error=None）
- `CommandResult::success_with_output(msg)` — 创建带输出的成功结果
- `CommandResult::failure(msg: String, exit_code?: Int=1)` — 创建失败结果，`exit_code` 默认为 1
- `CommandResult::is_success() -> Bool` — 判断是否成功

### 输出包装函数

为了避免子命令中大范围改写 `println`，同时保证运行时实时输出和测试可捕获，引入包装函数：

```moonbit
/// 同时打印到控制台并写入 CommandResult.output
fn print_to(result : CommandResult, msg : String) -> Unit {
  println(msg)
  result.output = result.output + msg + "\n"
}
```

> 注：MoonBit 没有 `print`（不换行）函数，只有 `println`，因此无需 `write_to` 包装。如果需要拼接不换行内容，可在调用侧手动拼接字符串后统一调用 `print_to`。

**优势**：
- 子命令只需将 `println(msg)` → `print_to(result, msg)`，改动最小
- 运行时输出仍然实时打印到控制台（长耗时命令如 `install` 仍可实时显示进度）
- `result.output` 同时捕获了所有输出，测试可断言
- 主入口无需重新打印 `result.output`，避免重复输出

### 子进程输出捕获 — C FFI 方案

**问题**：`run_run` 子命令通过 `@mvm_cmd.run()` → `@process.run()` 执行子进程，该函数会流式输出到控制台但无法获取输出内容。而 `@process.collect_output_merged()` 能获取输出但不会流式输出到控制台。MoonBit 目前没有同时支持流式输出和内容捕获的 API。

**解决方案**：在 `command` 包中新增 C FFI 函数 `run_with_output`，用 C 实现子进程执行，同时流式输出到控制台并捕获 stdout 内容。

```moonbit
// command/ffi.mbt（仅 native 目标）
///|
/// 执行子进程，同时流式输出到控制台并捕获 stdout
/// 返回 (exit_code, captured_output)
extern "c" fn run_with_output(
      cmd : Bytes,        // UTF-8 命令路径
      args : Array[Bytes], // UTF-8 参数数组
      envs : Array[Bytes], // UTF-8 环境变量数组（"KEY=VALUE" 格式）
) -> RunOutput = "mvm_run_with_output"

///|
/// 子进程执行结果（C FFI 返回）
struct RunOutput {
      exit_code : Int
      output : Bytes  // UTF-8 编码的捕获输出
}
```

```c
// command/run_capture.c
// 实现：fork + exec + pipe，读取子进程 stdout，
// 每读到一块数据就同时 write 到 STDOUT_FILENO（控制台流式输出）和 buffer（捕获）
// 等待子进程结束后，返回 exit_code 和 captured buffer
```

**C 实现要点**：
- 使用 `fork()` + `execvp()` 创建子进程
- 创建 pipe 捕获子进程 stdout
- 父进程循环 `read(pipe_fd)` 读取数据块
- 每个数据块同时 `write(STDOUT_FILENO, ...)`（流式输出到控制台）和追加到 buffer
- 子进程结束后，返回 `{exit_code, captured_output_bytes}`
- 需要在 `moon.pkg` 中配置 `"native-stub": ["run_capture.c"]` 和 `"targets": {"ffi.mbt": ["native"]}`

> 注：此 C FFI 仅用于 `run_run` 子命令的子进程执行。其他子命令（如 `help`、`version` 等）的输出通过 `print_to` 包装函数捕获，不需要 C FFI。

### 核心改动流程

1. **定义 `CommandResult`** — 在 `run.mbt` 或新建 `result.mbt` 中定义类型及方法
2. **实现 C FFI `run_with_output`** — 在 `command` 包中添加 C stub 和 MoonBit extern 声明
3. **修改 `run` 函数签名** — `pub async fn run(Command) -> CommandResult`
4. **逐个修改子命令** — 每个子命令处理器从 `-> Unit` 改为 `-> CommandResult`：
         - `run_help()` → 用 `print_to` 构建输出
         - `run_version()` → 用 `print_to` 捕获 VERSION
         - `run_run()` → 用 C FFI `run_with_output` 获取子进程输出 + 退出码，写入 `CommandResult`
         - 其他子命令类似改造
5. **主入口适配** — 调用方拿到 `CommandResult` 后：
         - `result.error` → 打印到 stderr（如有）
         - 进程退出码 → `result.exit_code`
         - **无需重新打印 `result.output`**（包装函数和 C FFI 已实时流式输出）

### 输出捕获策略

**核心原则：`CommandResult.output` 只捕获命令的「实际结果输出」，不捕获日志信息。**

两类输出的区分规则：
- **`println(msg)`** → 命令的实际输出结果（如 `node -v` 的版本号 `v18.x.x`、帮助信息、版本号等）→ **改用 `print_to(result, msg)`，同时打印到控制台 + 写入 `result.output`**
- **`@log.debug/info/warn(msg)`** → 仅用于排查问题的日志信息（如 `@log.debug("run_run参数 ...")`、`@log.info("未安装，正在自动安装...")` 等）→ **保持原样不改，不放入 `CommandResult.output`**

以 `mvm run node@18 -- node -v` 为例：
- `@log.debug("run_run参数 ...")` → 不捕获（仅调试信息）
- `@log.info("node@18 未安装，正在自动安装...")` → 不捕获（仅提示性日志）
- 子进程 `node -v` 的输出 `v18.x.x` → **捕获到 `CommandResult.output`**（这才是命令的结果）

**其他改动**：
- `should_print_logo` 中 `@utils.print_logo()` → logo 是用户可见输出，需适配为使用 `print_to`
- 主入口无需重新打印 `result.output`（包装函数已实时打印），只需处理退出码和错误信息

### 错误处理策略

`raise fail(msg)` 保持原样不改。子命令内部仍可 `raise fail(msg)` 抛出错误，`run` 函数用 `try?` 捕获后转为 `CommandResult::failure(msg, code)`。子命令不需要改写错误处理方式。

## Implementation Plan

### 文件改动清单

| 文件 | 改动内容 |
|------|----------|
| 新建 `result.mbt` | 定义 `CommandResult` struct 及方法 |
| 新建 `command/run_capture.c` | C FFI stub：实现 `mvm_run_with_output`（fork+exec+pipe，流式输出+捕获） |
| 新建 `command/ffi.mbt` | MoonBit extern 声明 `run_with_output`，仅 native 目标 |
| `command/moon.pkg` | 添加 `"native-stub"` 和 `"targets"` 配置 |
| `command/cmd.mbt` | 新增 `run_with_output()` 公开包装方法 |
| `moon.pkg`（cmd/command） | 可能需导出 `CommandResult` |
| `run.mbt` | 修改 `run` 签名，捕获错误转为 `CommandResult` |
| `help.mbt` | `run_help() -> CommandResult`，用 `print_to` 替代 `println` |
| `version.mbt` | `run_version() -> CommandResult` |
| `run_run.mbt` | `run_run() -> CommandResult`，用 C FFI `run_with_output` 替代 `@mvm_cmd.run` |
| 其他子命令文件 | 类似改造，返回 `CommandResult` |
| `pkg.generated.mbti` | 更新 `run` 签名 |
| 主入口文件 | 适配 `CommandResult`，处理退出码和错误信息（无需重新打印 output） |

### 优先级

1. 先实现 `CommandResult` 类型和方法
2. 实现 C FFI `run_with_output`（子进程输出捕获）
3. 改造最简单的子命令（`version.mbt`）验证模式
4. 改造 `run.mbt` 调度层
5. 逐个改造其余子命令（特别注意 `run_run.mbt` 使用 C FFI）
6. 编写白盒测试

## Decisions

- **`CommandResult` 用 struct 而非 enum**：成功和失败共享 `output` 字段（失败也可能有输出），用 `exit_code` + `error` 区分状态更灵活
- **保持 raise 不改**：子命令内部仍可 `raise fail(msg)`，`run` 函数用 `try?` 捕获后转为 `CommandResult::failure`，子命令的错误处理方式不做任何改动
- **日志不属于 CommandResult**：`@log.debug/info/warn` 仅用于排查问题，保持原样不改、不放入 `CommandResult.output`。只有 `println` 产生的命令实际输出才需要通过 `print_to` 捕获
- **包装函数而非纯 write**：`print_to` 同时做 `println` + `result.output` 追加，子命令改动最小化，且保证运行时实时输出（长耗时命令的用户体验不变）
- **C FFI 解决子进程输出捕获**：MoonBit 的 `@process.run` 无法同时流式输出和捕获内容，因此用 C FFI 实现 `run_with_output` 函数，既保证终端实时输出体验不变，又能将子进程 stdout 内容捕获到 `CommandResult.output`

## Risks / Trade-offs

- **改动范围较大**：所有子命令处理器都需修改签名，需逐一测试回归；但包装函数策略大幅减少了每处改动的复杂度
- **日志与输出分离**：`@log` 输出一律不捕获到 `CommandResult.output`，只捕获 `println` 产生的命令实际结果。对于 `Run` 命令，只有子进程 stdout 的输出才放入 `result.output`
- **async 函数改造**：部分子命令是 `async fn`，`CommandResult` 需兼容异步场景
- **C FFI 跨平台兼容**：`run_capture.c` 使用 POSIX `fork/exec/pipe`，仅适用于 macOS/Linux；Windows 需要单独实现（可用 `_popen` 或 `CreateProcess` + pipe）