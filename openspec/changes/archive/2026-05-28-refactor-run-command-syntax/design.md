## Context

当前 `mvm run` 使用 `--` 作为工具版本与实际命令的分隔符（`mvm run node@18 -- node -v`）。这种设计与 mvm 其他子命令风格不一致，且与 Volta 的 `volta run --node 18 node app.js` 不兼容。Shim 代理脚本（`create_tool_cmd_unix` / `create_tool_cmd_windows`）也内嵌了 `--` 分隔符，需同步更新。

## Goals / Non-Goals

**Goals:**
- 支持位置参数语法：`mvm run node@18 node -v`（去掉 `--`）
- 支持 Volta 兼容语法：`mvm run --node 18 node app.js`
- Shim 代理脚本适配新语法
- 文档同步更新

**Non-Goals:**
- 不修改 `run_run.mbt` 的核心执行逻辑（执行流程不变，只改参数解析）
- 不修改 `Command` 枚举定义（`Run(Tool, String, Array[String])` 保持不变）

## Key Decisions

### 1. 解析策略：基于 `--` 前缀区分两种语法

在 `get_command` 中，`["run", first_arg, .. rest]` 匹配后，通过 `first_arg.has_prefix("--")` 判断语法类型：

- **`--` 开头** → Volta 兼容语法：`--node` → 工具名 `node`，`rest[0]` 为版本号，`rest[1..]` 为命令参数
- **非 `--` 开头** → 位置参数语法：`node@18` → `node` + `18`，`rest` 为命令参数

两种语法最终都构造 `Run(Tool, String, Array[String])`，区别仅在于 tool 和 version 的提取方式。

### 2. 错误处理

- `mvm run`（无参数）→ 保持错误提示 `command.run_no_tool_version`
- `mvm run node@18`（无命令参数）→ 保持错误提示 `run.empty_command`（在 `run_run` 中检查）
- `mvm run --node`（缺版本号）→ 新增错误提示
- `mvm run --node 18`（无命令参数）→ 保持错误提示 `run.empty_command`
- 原 `command.run_need_separator` 错误提示不再需要，改为通用错误提示

### 3. Shim 脚本变更

| 平台 | 旧语法 | 新语法 |
|------|--------|--------|
| Unix | `mvm run {tool} -- {cmd} "$@"` | `mvm run {tool} {cmd} "$@"` |
| Windows PS1 | `mvm run {tool} -- {cmd} $args` | `mvm run {tool} {cmd} $args` |
| Windows CMD | `@mvm run {tool} -- {cmd} %*` | `@mvm run {tool} {cmd} %*` |

Shim 脚本中 `{tool}` 不带版本号，运行时由 `get_program_exe_info` 从配置中解析版本。去掉 `--` 后，`{cmd}` 直接作为位置参数传入，解析为 `run_args[0]`。

## Risks / Trade-offs

- **向后不兼容**：`mvm run node@18 -- node -v` 不再有效。但 `--` 在 mvm 中仅 `run` 命令使用，影响面可控。用户需重新执行 `mvm setup` 以更新 shim 脚本。
- **Volta 兼容语法仅支持已知工具**：`--node`、`--bun`、`--go` 等必须对应 `Tool` 枚举中的已知值，不支持任意工具名。
