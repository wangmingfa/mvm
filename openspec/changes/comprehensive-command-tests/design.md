## Context

当前 `mvm_wbtest.mbt` 仅覆盖 `Command::Version` 和 `Command::Help`。`Command` 枚举有 21 个变体，`Tool` 枚举有 9 个变体。`run(Command)` 返回 `CommandResult`（output/exit_code/error），所有子命令处理器已统一返回 `CommandResult`。`Run` 命令使用 `@mvm_cmd.run_with_output` C FFI 捕获子进程 stdout。

## Goals / Non-Goals

**Goals:**
- 为所有 21 个 Command 变体补充白盒测试
- 重点覆盖 `Command::Run`，测试常用外部工具（npm -v、npx -v、bunx -v、rustc -v 等）
- 验证 `CommandResult` 的 exit_code、output、error 字段在不同命令下的正确性
- 验证 `plain_output()` 去色后在动态内容测试中的实用性

**Non-Goals:**
- 不测试 Install/Setup/Uninstall 等会修改磁盘状态的命令（需要真实环境安装）
- 不测试 Upgrade 等需要网络请求的命令
- 不测试 ConfigSet/ConfigPreset 等会修改配置文件的命令
- 不重构测试架构或提取测试辅助函数（仅新增测试）

## Approach

测试按命令特性分为三类，采用不同断言策略：

### 1. 纯输出命令（确定性断言）
- `Version`：已有，exit_code=0，output 可用 `inspect` 精确匹配
- `Help`：已有，exit_code=0，output 包含关键字用 `assert_true`
- `ConfigList`：exit_code=0，output 包含配置项关键字
- `UpgradeList`：exit_code=0，output 包含版本列表格式
- `CacheClean`：exit_code=0，output 包含清理结果信息
- `Current(None)` / `Current(Some(tool))`：exit_code=0，output 包含当前版本信息

### 2. 需要本地环境的命令（半确定性断言）
- `List(None)` / `List(Some(tool))`：exit_code=0，output 包含已安装列表格式
- `Which(tool)`：exit_code=0，output 包含工具路径；或 exit_code!=0（工具未安装）
- `Use(tool, version)`：需要已安装版本
- `Unuse(tool)`：需要已使用的工具

### 3. Run 命令（核心重点测试）
- 测试 mvm 管理的工具：`Run(Node, "", ["node", "-v"])`、`Run(Node, "", ["npm", "-v"])`、`Run(Node, "", ["npx", "-v"])`
- 测试常用外部工具：`Run(Rust, "", ["rustc", "-v"])` 或 `cargo -v`、`Run(Bun, "", ["bunx", "-v"])`、`Run(Go, "", ["go", "version"])`
- 断言策略：exit_code=0（成功情况），output 使用 `plain_output()` + `assert_true(.contains())` 做动态内容匹配
- 错误情况：`Run` 传入空 args 应返回 failure

### Run 命令测试矩阵

| 测试用例 | Tool | args | 断言策略 |
|---------|------|------|---------|
| node -v | Node | ["node", "-v"] | exit_code=0, output.contains("v") |
| npm -v | Node | ["npm", "-v"] | exit_code=0, output.matches 数字 |
| npx -v | Node | ["npx", "-v"] | exit_code=0, output.matches 数字 |
| bunx -v | Bun | ["bunx", "-v"] | exit_code=0 或 工具未安装 |
| rustc -v | Rust | ["rustc", "-v"] | exit_code=0, output.contains("rustc") |
| go version | Go | ["go", "version"] | exit_code=0, output.contains("go") |
| 不存在的程序 | Node | ["nonexistent"] | exit_code!=0 或 failure |

## Technical Details

### 断言模式规范
- `exit_code` 是 Int 类型：使用 `inspect` 精确匹配
- `output` 是 String 类型：确定性内容用 `inspect`，动态内容用 `plain_output()` + `assert_true(.contains())`
- `error` 是 String? 类型：使用 `debug_inspect`（Option 的 Debug 表示）
- `is_success()` 是 Bool 类型：使用 `inspect`
- 整个 `CommandResult` 结构体：使用 `debug_inspect` 做快照断言（仅用于确定性输出）

### Run 命令测试注意事项
- `Run(Node, "", ["node", "-v"])`：版本号为空字符串，mvm 会自动使用当前目录的版本
- `Run(Node, "22", ["node", "-v"])`：指定版本 22
- 某些工具可能未安装（如 Deno、Java、Kotlin），测试应容许 failure 或 exit_code!=0
- 所有 Run 测试使用 `async test`，因为 `run()` 是 async 函数

### 文件组织
所有测试写在 `mvm_wbtest.mbt` 中，按命令类别分组，每组用注释分隔：
```
// ========= 纯输出命令测试 =========
// ========= 需要本地环境的命令测试 =========
// ========= Run 命令测试 =========
// ========= 错误命令测试 =========
```

## Risks / Trade-offs

- **环境依赖**：Run 命令测试依赖本地已安装的工具版本，不同环境可能产生不同结果。使用 `plain_output()` + `contains()` 缓解
- **测试稳定性**：部分命令（Which、Current、List）依赖本地 mvm 安装状态，可能因环境不同而失败。通过容许两种结果（成功/失败）来缓解
- **测试执行时间**：Run 命令会真实启动子进程，每个测试约 0.5-2 秒。需控制测试数量避免过长
