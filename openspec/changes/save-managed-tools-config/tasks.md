# Tasks: Save Managed Tools to Config

## 1. 添加 i18n 文案

- [x] 1.1 在 `i18n/zh.mbt` 中添加：
  - `config.managed_tools`: "被管理的工具"
  - `config.managed_tools_all`: "所有工具（默认）"
- [x] 1.2 在 `i18n/en.mbt` 中添加：
  - `config.managed_tools`: "Managed Tools"
  - `config.managed_tools_all`: "All tools (default)"

## 2. setup 命令保存 managed_tools

- [x] 2.1 修改 `cmd/command/setup.mbt` 的 `run_setup` 函数
- [x] 2.2 在确定 `managed_tools` 后，将其转换为逗号分隔字符串
- [x] 2.3 调用 `@tools.get_global_config()` 获取现有配置
- [x] 2.4 调用 `@tools.make_global_config(existing_config~, managed_tools=Some(managed_tools_str))` 创建新配置
- [x] 2.5 调用 `@tools.save_global_config(new_config)` 保存配置

## 3. config ls 显示 managed_tools

- [x] 3.1 修改 `cmd/command/config.mbt` 的 `run_config` 函数
- [x] 3.2 在函数末尾添加 managed_tools 的显示逻辑
- [x] 3.3 处理 `Some(str)` 和 `None` 两种情况

## 4. list 命令过滤工具

- [x] 4.1 修改 `cmd/command/list.mbt` 的 `run_list` 函数
- [x] 4.2 当 `tool` 参数为 `None` 时，调用 `@tools.get_global_config()` 获取配置
- [x] 4.3 调用 `@tools.get_managed_tools(global_config)` 获取被管理的工具列表
- [x] 4.4 替换原来的 `@tools.Tool::installable_tools()`

## 5. setup 启动时自动选中之前保存的工具

- [x] 5.1 修改 `stdio/multi_select.c` 的 `multi_select` 函数
  - 增加第二个参数 `const char* preselected`
  - 在构建 items 后，解析 preselected 字符串
  - 将匹配的工具标记为 `checked=1`
- [x] 5.2 修改 `stdio/interactive_select.c` 的 `interactive_select_tools_c` 函数
  - 增加第二个参数 `const char* preselected`
  - 将 preselected 传递给 `multi_select`
- [x] 5.3 修改 `stdio/print.mbt` 的 FFI 签名
  - 更新 `c_interactive_select_tools` 增加 `preselected : Bytes` 参数
  - 更新 `interactive_select_tools_c` 包装函数增加 preselected 参数
- [x] 5.4 修改 `cmd/command/setup.mbt` 的 `interactive_select_tools` 函数
  - 调用 `@tools.get_global_config()` 获取配置
  - 从 `global_config.managed_tools` 读取之前保存的工具
  - 将工具列表传递给 `interactive_select_tools_c`

## 6. 测试验证

- [ ] 6.1 测试 setup 后 config.json 中是否正确保存了 managed_tools
- [ ] 6.2 测试 `mvm config ls` 是否正确显示 managed_tools
- [ ] 6.3 测试 `mvm ls` 是否只显示被管理的工具
- [ ] 6.4 测试向后兼容性：没有 managed_tools 字段时，list 显示所有工具
- [ ] 6.5 测试 setup 启动时是否正确自动选中之前保存的工具
