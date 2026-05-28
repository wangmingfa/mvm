## 1. 命令解析逻辑修改

- [x] 1.1 修改 `cmd/command/command.mbt` 中 `get_command` 函数的 `["run", ..]` 分支：移除 `--` 分隔符依赖，改为位置参数直接解析
- [x] 1.2 新增 `["run", "--" + tool, version, .. run_args]` 分支，支持 Volta 兼容语法（`mvm run --node 18 node app.js`）
- [x] 1.3 为 `--` flag 形式添加错误处理：未知工具提示、缺少版本号提示
- [x] 1.4 更新 `get_command` 的 run 命令相关测试用例，覆盖新语法和 Volta 兼容语法
- [x] 1.5 更新 i18n 中 `run` 相关的错误提示文本（`zh.mbt` 和 `en.mbt`），移除 `command.run_need_separator`，新增 Volta 兼容相关提示

## 2. Shim 代理脚本更新

- [x] 2.1 修改 `cmd/tools/common.mbt` 中 `create_tool_cmd_unix` 的脚本内容：去掉 `--` 分隔符
- [x] 2.2 修改 `cmd/tools/common.mbt` 中 `create_tool_cmd_windows` 的 `.ps1` 和 `.cmd` 脚本内容：去掉 `--` 分隔符

## 3. 文档同步更新

- [x] 3.1 更新 `README.md` 中 `mvm run` 的使用示例，替换为新语法并添加 Volta 兼容语法说明
- [x] 3.2 更新 `README.md` 中"工作原理"章节的 Shim 脚本示例，去掉 `--`
- [x] 3.3 同步更新 `README_en.md`（英文 README）中的对应内容
