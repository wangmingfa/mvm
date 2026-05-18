## Why

当前 `run(Command) -> Unit` 及所有子命令处理器（如 `run_help()`、`run_version()`、`run_run()` 等）均返回 `Unit`，输出直接通过 `println`/`@log` 打印到控制台。这使得白盒测试无法通过返回值来断言执行结果是否正确，只能在测试中调用 `run` 却无法验证其行为。

具体问题：
- `mvm_wbtest.mbt` 中调用了 `@command.run(Run(Node, "", ["node", "-v"]))`，但因为 `run` 返回 `Unit`，无法对结果做任何逻辑断言
- 子命令如 `run_version()` 只是 `println(VERSION)`，测试无法捕获输出内容
- 错误场景通过 `raise fail()` 报错，成功场景则静默返回 `Unit`，成功与失败无法统一表达

## What

引入一个 `CommandResult` 类型作为命令执行的返回值，替代当前的 `Unit` 返回。该类型应能：
- 捕获命令的标准输出内容（替代直接 `println`）
- 表达命令执行成功/失败的状态和退出码
- 在测试中可进行结构化断言（如检查输出文本、退出码等）

主要改动方向：
1. 定义 `CommandResult` 类型（包含输出文本、退出码、错误信息等字段）
2. 将 `run(Command) -> Unit` 改为 `run(Command) -> CommandResult`
3. 将各子命令处理器从返回 `Unit` 改为返回 `CommandResult`
4. 将子命令中的 `println`/`@log` 输出改为写入 `CommandResult`
5. 主入口仍将 `CommandResult` 的内容打印到控制台（保持用户体验不变）
6. 利用 `CommandResult` 在白盒测试中进行断言

## Impact

- **受影响代码**：`cmd/command/` 下的所有子命令文件（`help.mbt`、`version.mbt`、`install.mbt`、`run_run.mbt`、`setup.mbt` 等）以及 `run.mbt` 的调度逻辑
- **受影响 API**：`pub async fn run(Command) -> Unit` 的签名变更，所有调用方（如主入口）需适配
- **受影响测试**：`mvm_wbtest.mbt` 可利用新的返回值编写真正的断言测试；`command.mbt` 中的现有解析测试不受影响
- **受影响依赖**：`pkg.generated.mbti` 中 `run` 的签名需更新
