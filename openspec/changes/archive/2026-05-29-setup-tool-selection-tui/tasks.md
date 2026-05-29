## 1. 扩展 GlobalConfig — 新增 managed_tools 字段

> **背景**：当前 `GlobalConfig` 仅包含镜像代理和语言配置，需要新增 `managed_tools` 字段来持久化用户的工具选择。`managed_tools` 为 `None` 时管理所有工具（向后兼容），为 `Some("node,bun,go")` 时仅管理指定工具。

- [ ] 1.1 在 `tool_def/config.mbt` 中为 `GlobalConfig` 新增 `managed_tools : String?` 字段，更新 `derive(FromJson, ToJson)`
- [ ] 1.2 更新 `make_global_config` 函数，新增 `managed_tools? : String? = None` 参数
- [ ] 1.3 更新 `GlobalConfig::to_string` 方法，增加 `managed_tools` 的展示
- [ ] 1.4 更新 `get_global_config` 中的默认值构造，增加 `managed_tools: None`
- [ ] 1.5 新增 `get_managed_tools(global_config : GlobalConfig) -> Array[Tool]` 辅助函数：`None` 返回所有工具，`Some(str)` 解析逗号分隔列表
- [ ] 1.6 新增 `validate_managed_tools_value(value : String) -> Array[Tool]` 校验函数：验证逗号分隔的工具名是否合法
- [ ] 1.7 编写测试：`get_managed_tools` 返回全部 / 返回指定 / 空字符串 / 非法工具名

## 2. 实现 C FFI 终端交互

> **背景**：TUI 需要在 raw mode 下读取键盘输入（无需等待回车），需要通过 C FFI 调用 POSIX `tcgetattr/tcsetattr` 和 `read()`。

- [ ] 2.1 新建 `ffi/terminal.c`，实现 `mvm_terminal_set_raw`、`mvm_terminal_restore`、`mvm_terminal_read_key` 三个 C 函数
  - `set_raw(fd)`：使用 `tcgetattr/tcsetattr` 设置终端为 raw mode（禁用 ECHO、ICANON 等）
  - `restore(fd)`：恢复原始终端属性
  - `read_key(fd)`：`read()` 读取字节，解析 ANSI escape sequences 识别方向键
- [ ] 2.2 新建 `ffi/terminal.mbt`，声明 MoonBit FFI 类型和函数
  - 定义 `TerminalKey` 枚举（Up/Down/Space/Enter/Quit/SelectAll/Unknown(String)）
  - extern "c" 声明三个 C FFI 函数
  - 包装方法 `terminal_set_raw()` / `terminal_restore()` / `terminal_read_key()`
- [ ] 2.3 修改 `ffi/moon.pkg`，添加 `"native-stub": ["terminal.c"]` 和 `"targets"` 配置
- [ ] 2.4 新增 `mvm_terminal_isatty` C FFI：检测 stdin 是否为终端（用于 CI 环境回退）
- [ ] 2.5 编写终端交互的基础测试（在 CI 中可跳过，仅本地验证）

## 3. 实现 TUI 交互选择逻辑

> **背景**：需要用 ANSI escape codes 在终端中渲染工具多选列表，支持光标移动、选择切换、全选、确认。

- [ ] 3.1 新建 `cmd/command/tui.mbt`，定义 `ToolSelectionState` 结构体
  ```moonbit
  struct ToolSelectionState {
    cursor : Int           // 当前光标位置（0-based）
    selected : Set[Tool]   // 已选中的工具集合
    all_tools : Array[Tool] // 所有可选工具
  }
  ```
- [ ] 3.2 实现 `render_tool_selection(state : ToolSelectionState)` 渲染函数
  - 使用 ANSI escape codes（`\x1b[2J\x1b[H` 清屏，`\x1b[{n}A/B` 移动光标）
  - 渲染标题、操作提示、工具列表（选中 `[✓]`、未选中 `[ ]`、已安装标注版本号）
  - 当前光标行用反色高亮（`\x1b[7m` / `\x1b[27m`）
- [ ] 3.3 实现 `handle_key_event(state : ToolSelectionState, key : TerminalKey) -> ToolSelectionState` 事件处理
  - Up/Down：移动光标
  - Space：切换选中
  - a：全选/取消全选
  - Enter：确认，返回最终选中列表
  - Quit：取消，返回 None
- [ ] 3.4 实现 `show_tool_selection_tui(global_config : GlobalConfig) -> Array[Tool]?` 主循环
  - 初始化 `ToolSelectionState`：默认选中已安装工具或按 `managed_tools` 配置
  - 循环：渲染 → 读取按键 → 处理事件 → 重新渲染
  - 确认后返回选中工具列表
  - 非交互终端（`isatty` 为 false）时回退为"管理所有已安装工具"
- [ ] 3.5 实现 `ask_if_reselect() -> Bool`：已有 `managed_tools` 配置时，询问是否重新选择（简单 y/n 问答，无需 TUI）

## 4. 改造 setup 命令

> **背景**：将 `run_setup` 从"全量创建 shim"改为"按 managed_tools 选择创建 shim"。

- [ ] 4.1 修改 `run_setup` 函数，增加 TUI 选择流程
  - 获取 `GlobalConfig`，确定 `managed_tools`
  - `managed_tools` 未设置 → 调用 `show_tool_selection_tui`
  - `managed_tools` 已设置 → 调用 `ask_if_reselect`，用户选 y 则重新 TUI 选择
  - 保存 `managed_tools` 到 `GlobalConfig`
- [ ] 4.2 修改 shim 创建逻辑，从"遍历 `Tool::all_tools()`"改为"遍历 `managed_tools`"
  - 改造 `create_new_shims`：接受 `managed_tools` 参数，仅为选中工具创建 shim
  - 新增 `cleanup_unmanaged_shims`：删除不在 `managed_tools` 中的旧 shim
- [ ] 4.3 修改 `print_success_unix/print_success_windows`，只展示 managed 工具列表
- [ ] 4.4 处理 `managed_tools` 为 `None`（未设置）的情况：首次 setup 调用 TUI，向后兼容

## 5. 改造 config 命令

> **背景**：让用户可以通过 `config list` 查看 `managed_tools`，通过 `config set` 设置并自动重建 shim。

- [ ] 5.1 修改 `run_config`，增加 `managed_tools` 的展示
  - `Some(str)` → 展示具体的工具列表
  - `None` → 展示"管理所有工具（默认）"
- [ ] 5.2 修改 `run_config_set`，增加 `"managed_tools"` 键的处理
  - 校验值：调用 `validate_managed_tools_value`
  - 保存到 `GlobalConfig`
  - 自动重建 shim：删除旧 shim → 创建新 shim
- [ ] 5.3 在不支持的配置键提示中增加 `managed_tools` 说明

## 6. 补充 i18n 文案

> **背景**：新增 TUI 相关和 managed_tools 相关的国际化文案。

- [ ] 6.1 在 `i18n/zh.mbt` 中新增文案：
  - TUI 选择标题、操作提示
  - managed_tools 配置项名称和描述
  - 重新选择提示
  - shim 重建提示
- [ ] 6.2 在 `i18n/en.mbt` 中新增对应的英文文案

## 7. 编写测试

> **背景**：确保 `managed_tools` 的配置解析、校验、shim 创建逻辑正确。

- [ ] 7.1 `tool_def/config.mbt` 测试：`get_managed_tools` / `validate_managed_tools_value` 各种场景
- [ ] 7.2 `setup.mbt` 测试：验证 `managed_tools` 为 None / Some 时的 shim 创建逻辑
- [ ] 7.3 `config.mbt` 测试：验证 `managed_tools` 的展示和设置逻辑
