# Proposal: Save Managed Tools to Config

## Motivation

当前 `mvm setup` 命令允许用户选择要管理的工具，但这些选择没有被持久化保存。每次运行 setup 都需要重新选择，且其他命令（如 `mvm ls`）无法感知用户实际管理的工具集合。

## Goals

1. **持久化管理工具选择**：将 setup 中选择的 managed_tools 保存到 `~/.mvm/config.json` 的 `managed_tools` 字段
2. **config 命令兼容**：`mvm config ls` 能够显示当前管理的工具列表
3. **list 命令过滤**：`mvm ls` 只显示被管理的工具，而不是所有可安装工具

## Non-Goals

- 不改变现有的工具安装/卸载逻辑
- 不引入新的配置文件格式
- 不修改 `mvm use`、`mvm install` 等命令的行为

## Impact

- **用户配置**：`~/.mvm/config.json` 新增 `managed_tools` 字段
- **setup 命令**：选择后自动保存到配置
- **config 命令**：支持显示和设置 managed_tools
- **list 命令**：根据配置过滤显示的工具列表
- **向后兼容**：如果 `managed_tools` 字段不存在，默认管理所有工具（现有行为）
