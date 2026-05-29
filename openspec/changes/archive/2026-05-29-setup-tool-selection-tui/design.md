## Context

当前 mvm 的 `setup` 命令为所有 9 种工具（Node、Bun、Zig、Go、Python、Rust、Deno、Java、Kotlin）无差别创建 shim 脚本，并将 `~/.mvm/bin` prepend 到 PATH 最前面。shim 脚本的内容形如 `#!/bin/sh\nmvm run {tool} {cmd} "$@"`，会拦截所有对同名命令的调用。

这导致了一个严重问题：即使用户只通过 mvm 管理 Node，`~/.mvm/bin/cargo` shim 也会拦截 rustup 安装的 cargo，使 `cargo metadata` 被路由到 `mvm run rust cargo "$@"` 并失败。

GlobalConfig 当前结构（存储在 `~/.mvm/config.json`）仅包含镜像代理和语言配置，没有工具管理范围的配置。

## Goals / Non-Goals

**Goals:**
- 让用户在 `mvm setup` 时通过 TUI 交互选择需要被 mvm 管理的工具
- 仅为选中的工具创建 shim 脚本，未选中的工具不创建 shim（避免拦截系统中已有的同名工具）
- 将用户选择持久化到 `GlobalConfig.managed_tools` 字段
- 支持通过 `mvm setup` 重新选择或通过 `mvm config set managed_tools node,bun,go` 直接设置
- `mvm config list` 展示 managed_tools 配置项

**Non-Goals:**
- 不实现复杂的多面板 TUI（不需要依赖 crossterm/termion 等第三方 TUI 库）
- 不改变 `mvm run` 命令的行为（`mvm run` 仍然可以运行任何已安装的工具，不受 managed_tools 限制）
- 不改变 `mvm use/install/uninstall` 等命令的行为（这些命令仍然可以操作所有工具，不受 managed_tools 限制）
- 不支持项目级别的 managed_tools 配置（仅全局配置）

## Architecture

### GlobalConfig 新增 managed_tools 字段

在 `GlobalConfig` 中新增 `managed_tools` 字段，类型为 `String?`（存储逗号分隔的工具名列表）：

```moonbit
pub(all) struct GlobalConfig {
  github_proxy : String?
  node_mirror : String?
  go_mirror : String?
  python_mirror : String?
  rust_mirror : String?
  java_mirror : String?
  language : String?
  // 新增：被 mvm 管理的工具列表，逗号分隔，如 "node,bun,go"
  // None 或空字符串表示管理所有工具（向后兼容）
  managed_tools : String?
} derive(FromJson, ToJson)
```

**向后兼容**：`managed_tools` 为 `None` 时，`setup` 行为与当前一致（管理所有工具），确保已有用户不受影响。只有显式设置后才会按选择创建 shim。

### 获取 managed_tools 列表的辅助函数

```moonbit
/// 获取当前被管理的工具列表
/// managed_tools 为 None 时返回所有工具（向后兼容）
/// managed_tools 为 Some("") 时返回空列表
/// managed_tools 为 Some("node,bun") 时返回 [Node, Bun]
pub fn get_managed_tools(global_config : GlobalConfig) -> Array[Tool] {
  match global_config.managed_tools {
    None => Tool::all_tools()  // 向后兼容：未设置时管理所有工具
    Some(str) => {
      if str.is_blank() {
        []
      } else {
        str.split(",")
          .filter(v => !v.is_blank())
          .map(v => Tool::from_string(v.trim()) catch { _ => return None })
          .filter(v => v is Some(_))
          .map(v => v.unwrap())
          .to_array()
      }
    }
  }
}
```

### TUI 交互选择实现

采用轻量级 ANSI 终端交互方案（不依赖第三方 TUI 库），使用纯文本 + ANSI escape codes 实现：

```
╭───────────────────────────────────────╮
│  选择需要被 mvm 管理的工具             │
│  ↑/↓ 移动  空格选择  a 全选  回车确认  │
╰───────────────────────────────────────╯

  [✓] node     (已安装: v20.11.0)
  [✓] bun      (已安装: v1.1.29)
  [ ] zig
  [✓] go       (已安装: v1.23.0)
  [ ] python
  [ ] rust
  [ ] deno
  [ ] java
  [ ] kotlin
```

**交互方式**：
- `↑/↓` 或 `j/k`：移动光标
- `空格`：切换选中状态
- `a`：全选/取消全选
- `回车`：确认选择
- `q` 或 `Ctrl+C`：取消退出

**默认选中逻辑**：
- 已通过 mvm 安装的工具默认选中
- 未安装的工具默认未选中
- 如果已有 `managed_tools` 配置，则按配置初始化选中状态

**实现方式**：
1. 通过 C FFI 获取终端的原始模式（raw mode），使用 `tcgetattr/tcsetattr` 设置
2. 读取键盘输入（无需等待回车）
3. 使用 ANSI escape codes 控制光标位置和渲染
4. 确认后将选中结果写入 `GlobalConfig.managed_tools`

### C FFI 终端交互

新增 C FFI 函数用于终端原始模式设置和单字符输入读取：

```moonbit
// 在 ffi 包中新增

/// 设置终端为原始模式（raw mode），禁用回车等待和回显
extern "c" fn mvm_terminal_set_raw(fd : Int) -> Unit

/// 恢复终端为正常模式
extern "c" fn mvm_terminal_restore(fd : Int) -> Unit

/// 读取单个键盘输入（raw mode 下），返回输入字节序列
/// 支持识别方向键等特殊按键
extern "c" fn mvm_terminal_read_key(fd : Int) -> TerminalKey
```

```moonbit
/// 终端按键枚举
pub(all) enum TerminalKey {
  Up       // ↑ 或 k
  Down     // ↓ 或 j
  Space    // 空格
  Enter    // 回车
  Quit     // q 或 Ctrl+C
  SelectAll // a
  Unknown(String)  // 其他输入
}
```

新增 C stub 文件 `ffi/terminal.c`，实现 POSIX 终端 raw mode 设置和按键读取：
- 使用 `tcgetattr/tcsetattr` 设置终端属性
- 使用 `read()` 读取输入字节
- 解析 ANSI escape sequences 识别方向键（`\x1b[A` = Up, `\x1b[B` = Down）

### setup 命令改造

`run_setup` 改为两阶段流程：

**阶段 1 — TUI 选择**：
- 如果 `managed_tools` 未设置，显示 TUI 让用户选择
- 如果 `managed_tools` 已设置，询问是否重新选择（y/n），选 n 则使用现有配置

**阶段 2 — 创建 shim**：
- 仅为 `managed_tools` 中选中的工具及其可执行程序创建 shim
- 删除不在 `managed_tools` 中的旧 shim 脚本

```moonbit
async fn run_setup(use_prefix : Bool) -> CommandResult {
  // 1. 获取当前 GlobalConfig
  let (_, global_config) = @tools.get_global_config()
  
  // 2. 确定 managed_tools
  let managed_tools = if global_config.managed_tools is None {
    // 未设置，进入 TUI 选择
    let selected = show_tool_selection_tui(global_config)
    // 保存到 GlobalConfig
    save_managed_tools_to_config(selected)
    selected
  } else {
    // 已设置，询问是否重新选择
    if ask_if_reselect() {
      let selected = show_tool_selection_tui(global_config)
      save_managed_tools_to_config(selected)
      selected
    } else {
      @tools.get_managed_tools(global_config)
    }
  }
  
  // 3. 仅为 managed_tools 创建 shim
  create_shims_for_tools(managed_tools, use_prefix)
  
  // 4. 配置 PATH、打印成功消息等（与现有逻辑一致）
  ...
}
```

### config 命令改造

**`mvm config list`** 增加 `managed_tools` 展示：
```moonbit
// 在 run_config() 中增加：
print_to(result, @i18n.t("config.managed_tools"))
match config.managed_tools {
  Some(str) => print_to(result, @i18n.t("config.list_key", args={ "key": "managed_tools", "value": str }))
  None => print_to(result, @i18n.t("config.list_key", args={ "key": "managed_tools", "value": @i18n.t("config.managed_tools_all") }))
}
```

**`mvm config set managed_tools node,bun,go`**：
```moonbit
// 在 run_config_set() 中增加：
"managed_tools" => {
  // 校验值：必须是逗号分隔的合法工具名
  let tools = validate_managed_tools_value(value)
  let new_config = @tools.make_global_config(
    existing_config~,
    managed_tools=Some(value),
  )
  let config_path = @tools.save_global_config(new_config)
  // 删除旧 shim，创建新 shim
  recreate_shims_for_managed_tools(tools)
  print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
  print_to(result, @i18n.t("config.set_value", args={ "key": "managed_tools", "value": value }))
}
```

### Shim 创建逻辑改造

将 `create_new_shims` 和 `cleanup_old_shims` 改为基于 `managed_tools` 列表：

```moonbit
/// 仅为 managed_tools 创建 shim
async fn create_shims_for_tools(
  managed_tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  let os = @os.get_os_name()
  for tool in managed_tools {
    let executable_names = tool.get_executable_programs()
    for name in executable_names {
      let belonging_tool = @tools.Tool::get_belonging_tool(name)
      let cmd_name = name
      match os {
        MacOS | Linux =>
          @tools.create_tool_cmd_unix(belonging_tool, cmd_name, file_name=prefix_str + cmd_name)
        Windows =>
          @tools.create_tool_cmd_windows(belonging_tool, cmd_name, file_name=prefix_str + cmd_name)
        _ => ()
      }
    }
  }
}

/// 删除不在 managed_tools 中的 shim
async fn cleanup_unmanaged_shims(
  managed_tools : Array[Tool],
  bin_dir : String,
) -> Unit {
  let all_tools = Tool::all_tools()
  let unmanaged_tools = all_tools.filter(t => !managed_tools.contains(t))
  let delete_names = []
  for tool in unmanaged_tools {
    delete_names.push(tool.to_string())
    delete_names.append(tool.get_executable_programs())
  }
  remove_names(bin_dir, delete_names)
}
```

## Implementation Plan

### 文件改动清单

| 文件 | 改动内容 |
|------|----------|
| `tool_def/config.mbt` | `GlobalConfig` 新增 `managed_tools` 字段，`make_global_config` 增加参数，新增 `get_managed_tools` 和 `validate_managed_tools_value` 函数 |
| `tool_def/config.mbt` 测试 | 新增 `managed_tools` 相关测试 |
| `setup.mbt` | 改造 `run_setup` 流程：TUI 选择 → 仅为选中工具创建 shim → 清理未选中工具的 shim |
| `config.mbt` | `run_config` 增加 `managed_tools` 展示，`run_config_set` 增加 `managed_tools` 设置并重建 shim |
| 新建 `cmd/command/tui.mbt` | TUI 交互选择逻辑（渲染、键盘事件处理、选中状态管理） |
| 新建 `ffi/terminal.c` | C FFI stub：终端 raw mode 设置/恢复、按键读取 |
| 新建 `ffi/terminal.mbt` | MoonBit FFI 声明：`TerminalKey` 枚举、终端操控函数 |
| `ffi/moon.pkg` | 添加 `"native-stub": ["terminal.c"]` 和 targets 配置 |
| `i18n/zh.mbt` / `i18n/en.mbt` | 新增 TUI 和 managed_tools 相关的 i18n key |
| `cmd/command/moon.pkg` | 导入新的 TUI 和 terminal 模块 |
| `command/pkg.generated.mbti` | 更新导出签名 |

### 优先级

1. 先扩展 `GlobalConfig`，新增 `managed_tools` 字段和辅助函数
2. 实现 C FFI 终端交互（raw mode、按键读取）
3. 实现 MoonBit `TerminalKey` 枚举和 FFI 声明
4. 实现 TUI 渲染和交互逻辑
5. 改造 `setup` 命令（TUI 选择 + 按选择创建 shim）
6. 改造 `config` 命令（展示和设置 managed_tools）
7. 补充 i18n 文案
8. 编写测试

## Decisions

- **managed_tools 类型为 `String?`（逗号分隔）而非 `Array[String]`**：JSON 中数组需要更复杂的序列化，且 `mvm config set managed_tools node,bun,go` 的逗号分隔格式更符合 CLI 习惯。GlobalConfig 已有的 derive(FromJson, ToJson) 可以自动处理 String? 类型
- **None 表示管理所有工具（向后兼容）**：已有用户未设置 managed_tools 时，setup 行为不变。只有显式设置后才按选择创建 shim
- **轻量 ANSI TUI 而非第三方库**：mvm 是一个版本管理工具，不应引入复杂的 TUI 框架依赖。用 ANSI escape codes + C FFI raw mode 实现最简单的多选列表即��满足需求
- **TUI 默认选中已安装工具**：降低用户操作成本，已安装的工具大概率需要被管理
- **mvm run 不受 managed_tools 限制**：`mvm run rust cargo` 仍然可以运行，只是不会创建 rust 的 shim 脚本。用户可以显式通过 `mvm run` 使用任何已安装的工具

## Risks / Trade-offs

- **C FFI 终端交互的跨平台兼容**：POSIX raw mode 仅适用于 macOS/Linux，Windows 需要单独实现（使用 `_getch()` 或 Windows Console API）。可在 Windows 上回退到简单文本问答模式
- **向后兼容风险**：`managed_tools` 为 `None` 时保持原有行为（全量管理），但一旦用户设置后，之前全量的 shim 会被删除。需要在 TUI 确认时给出明确提示
- **TUI 在非交互终端中的行为**：当 stdin 不是终端（如 CI 环境或管道）时，TUI 无法工作。需要检测 `isatty()` 并回退到默认行为（管理所有已安装的工具）
- **ANSI escape codes 兼容性**：部分老旧终端可能不支持 ANSI escape codes，但现代终端（macOS Terminal、iTerm2、VSCode Terminal、Windows Terminal 等）均支持
