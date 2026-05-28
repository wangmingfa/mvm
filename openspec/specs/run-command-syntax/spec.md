## CHANGED Requirements

### Requirement: get_command 解析 run 命令的语法

`get_command` 中 `["run", ..]` 分支的解析逻辑变更：不再要求 `--` 分隔符，改为支持两种语法。

#### Scenario: 位置参数语法（基本用法）
- **WHEN** 调用 `get_command(["run", "node@18", "node", "-v"])`
- **THEN** 返回 `Run(Node, "18", ["node", "-v"])`

#### Scenario: 位置参数语法（无版本号）
- **WHEN** 调用 `get_command(["run", "node", "npm", "-v"])`
- **THEN** 返回 `Run(Node, "", ["npm", "-v"])`

#### Scenario: 位置参数语法（无命令参数）
- **WHEN** 调用 `get_command(["run", "node@18"])`
- **THEN** 返回 `Run(Node, "18", [])`，后续由 `run_run` 检查 `args.is_empty()` 并报错

#### Scenario: Volta 兼容语法（--node）
- **WHEN** 调用 `get_command(["run", "--node", "18", "node", "app.js"])`
- **THEN** 返回 `Run(Node, "18", ["node", "app.js"])`

#### Scenario: Volta 兼容语法（--bun）
- **WHEN** 调用 `get_command(["run", "--bun", "1.1.0", "bun", "run", "dev"])`
- **THEN** 返回 `Run(Bun, "1.1.0", ["bun", "run", "dev"])`

#### Scenario: Volta 兼容语法（未知工具）
- **WHEN** 调用 `get_command(["run", "--unknown", "1.0", "cmd"])`
- **THEN** 报错，提示不支持的 `--` 选项

#### Scenario: Volta 兼容语法（缺少版本号）
- **WHEN** 调用 `get_command(["run", "--node"])`
- **THEN** 报错，提示缺少版本号

#### Scenario: run 命令无参数
- **WHEN** 调用 `get_command(["run"])`
- **THEN** 报错，提示需要指定工具和版本（保持原有错误处理）

#### Scenario: 旧语法 `--` 分隔符不再支持
- **WHEN** 调用 `get_command(["run", "node@18", "--", "node", "-v"])`
- **THEN** `--` 被当作普通参数，解析为 `Run(Node, "18", ["--", "node", "-v"])`，由子进程执行时自行处理

---

### Requirement: Shim 脚本生成语法更新

`create_tool_cmd_unix` 和 `create_tool_cmd_windows` 生成的代理脚本不再包含 `--` 分隔符。

#### Scenario: Unix Shim 脚本内容
- **WHEN** 调用 `create_tool_cmd_unix(Node, "node")`
- **THEN** 生成的 shell 脚本内容为 `#!/bin/sh\nmvm run node node "$@"`

#### Scenario: Windows PS1 Shim 脚本内容
- **WHEN** 调用 `create_tool_cmd_windows(Node, "node")`
- **THEN** 生成的 `.ps1` 文件内容为 `mvm run node node $args`

#### Scenario: Windows CMD Shim 脚本内容
- **WHEN** 调用 `create_tool_cmd_windows(Node, "node")`
- **THEN** 生成的 `.cmd` 文件内容为 `@mvm run node node %*`

#### Scenario: Shim 脚本中包含 cmd_dir 参数
- **WHEN** 调用 `create_tool_cmd_unix(Node, "tsc", cmd_dir="npm")`
- **THEN** 生成的脚本路径为 `<mvm_bin>/npm/tsc`，内容为 `#!/bin/sh\nmvm run node tsc "$@"`
