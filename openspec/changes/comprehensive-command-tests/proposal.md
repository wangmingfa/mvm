## Why

当前 `mvm_wbtest.mbt` 白盒测试仅覆盖 `Command::Version` 和 `Command::Help` 两个命令，而 `Command` 枚举共有 21 个变体。大量核心命令（如 `Run`、`Install`、`Use`、`List`、`Config` 等）缺乏白盒测试覆盖，无法验证其 `CommandResult` 的输出格式、退出码和错误处理是否正确。

特别是 `Command::Run` 作为 mvm 的核心功能（代理运行外部工具），当前完全没有端到端白盒测试。除了验证 mvm 自身管理的工具外，还应验证其对常用外部工具的代理运行能力（如 `npm -v`、`npx -v`、`bunx -v`、`rustc -v` 等），确保 `run_with_output` C FFI 在真实环境中捕获子进程 stdout 的可靠性。

## Impact

- `mvm_wbtest.mbt`：新增所有命令的白盒测试函数
- `cmd/command/run.mbt` / `cmd/command/run_run.mbt`：`Run` 命令执行路径被测试覆盖
- `command/ffi.mbt`：`run_with_output` C FFI 端到端被测试验证
- 无 API 变更，仅新增测试代码
