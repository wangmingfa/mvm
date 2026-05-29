## Why

当前 `mvm setup` 命令为 **所有支持的工具**（Node、Bun、Zig、Go、Python、Rust、Deno、Java、Kotlin）无差别创建 shim 脚本，并将 `~/.mvm/bin` prepend 到 PATH 最前面。这导致以下问题：

1. **Shim 拦截问题**：mvm 为 `cargo`、`rustc` 等创建了 shim 脚本，即使用户并未通过 mvm 安装 Rust。这些 shim 会拦截系统中已有的同名工具（如 rustup 安装的 `~/.cargo/bin/cargo`），导致 `cargo metadata` 等命令被路由到 `mvm run rust cargo "$@"`，如果 mvm 未管理 Rust 则直接失败。用户反馈：用 mvm 的 node 运行 Tauri 工程时报 `cargo metadata` 失败，而 volta 或直接安装的 node 不报此错。

2. **缺乏选择性**：用户只能全量接受或全量拒绝所有工具的 shim 管理，无法按需选择只让 mvm 管理 Node 而不管理 Rust。

3. **配置不可持久化**：当前没有机制让用户的选择被记录下来，每次 `mvm setup` 都会重建所有 shim。

## What

为 `setup` 命令增加 **TUI 交互式工具选择** 功能：

- 运行 `mvm setup` 时，在终端中展示所有支持的工具列表，让用户通过键盘交互选择哪些工具需要被 mvm 管理（默认只选中已安装的工具）
- 仅为用户选中的工具创建 shim 脚本，未选中的工具不做拦截
- 用户选择结果写入 `~/.mvm/config.json` 的 `managed_tools` 字段，持久化保存
- 后续可通过 `mvm setup` 重新选择，或通过 `mvm config set managed_tools node,bun,go` 直接设置
- `mvm config list` 增加展示 `managed_tools` 配置项

## Impact

- **受影响命令**：`setup`（增加 TUI 交互流程）、`config list`（增加展示 managed_tools）、`config set`（增加 managed_tools 键支持）
- **受影响数据结构**：`GlobalConfig` 新增 `managed_tools` 字段
- **受影响文件**：`setup.mbt`（TUI 交互逻辑）、`config.mbt`（展示和设置 managed_tools）、`tool_def/config.mbt`（GlobalConfig 结构变更）、i18n 文件（新增翻译文案）
- **受影响行为**：`setup` 创建 shim 的逻辑从"全量创建"变为"按选择创建"，解决 shim 拦截其他工具的根因问题
