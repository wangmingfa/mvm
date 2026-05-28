## Why

当前 `mvm run` 命令语法要求使用 `--` 分隔符，例如 `mvm run node@18 -- node -v`，与所有其他 mvm 子命令的风格不统一（其他命令无需 `--`）。同时，mvm 作为受 Volta 启发的工具，应兼容 `volta run --node 18 node app.js` 的语法，降低 Volta 用户的迁移成本。

目标是将 `mvm run` 语法简化并扩展，支持以下两种调用方式：

1. **位置参数语法**（默认）：`mvm run node@18 node -v`（去掉 `--`）
2. **Volta 兼容语法**：`mvm run --node 18 node app.js`

相应的 Shim 代理脚本也需要更新以适配新语法。

## What Changes

- **命令解析**（`cmd/command/command.mbt`）：移除 `mvm run` 命令中的 `--` 分隔符要求，改为直接按位置参数解析；新增 `--<tool> <version>` flag 风格的 Volta 兼容解析
- **Shim 代理脚本**（`cmd/tools/common.mbt`）：`create_tool_cmd_unix` 和 `create_tool_cmd_windows` 生成的脚本内容去掉 `--` 分隔符
- **文档**：同步更新中英文 `README.md` 和 `README_en.md` 中 `mvm run` 的使用示例、工作原理说明中的 Shim 脚本示例
- **i18n**：更新 `run` 相关的错误提示文本以反映新语法

## Impact

- 受影响文件：
  - `cmd/command/command.mbt`——命令解析逻辑
  - `cmd/tools/common.mbt`——Shim 脚本生成
  - `README.md` / `README_en.md`——用户文档
  - `i18n/zh.mbt` / `i18n/en.mbt`——国际化文本（可能需要更新）
- 向后不兼容：已有的 `mvm run <tool>@<version> -- <cmd>` 语法将不再有效，用户需改为 `mvm run <tool>@<version> <cmd>` 或 `mvm run --<tool> <version> <cmd>`
