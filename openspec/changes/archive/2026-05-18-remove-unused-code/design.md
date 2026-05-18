## Context

mvm 项目经过多次迭代，积累了大量未使用的代码。通过全项目搜索分析（对比 `pkg.generated.mbti` 导出与实际 `@包名.函数` 外部调用），识别出两类问题：
1. **完全死代码**：全项目无任何调用的函数/方法
2. **过度暴露的公共 API**：标记为 `pub` 但仅在定义包内使用的函数

当前包的 `pkg.generated.mbti` 文件导出了许多实际不需要外部访问的函数，导致公共接口面积过大。**注意**：`pkg.generated.mbti` 文件已过时，其中的方法名与代码实际定义不一致（如 mbti 中 `is_java_builtin_tools` 对应代码中 `is_java_program`），本次分析基于代码中的实际方法名。

## Goals / Non-Goals

**Goals:**
- 删除所有全项目无调用的死代码函数/方法
- 将仅包内使用的 `pub` 函数降级为私有（移除 `pub` 关键字）
- 重新生成 `pkg.generated.mbti` 文件，使导出接口与实际使用匹配
- 确保所有现有测试继续通过

**Non-Goals:**
- 不重构包的结构或合并包
- 不删除测试代码（包内测试仍可访问私有函数）
- 不修改有外部调用的公共 API 的签名或行为
- 不处理注释中的代码片段（如被注释掉的旧实现）

## Approach

采用**两阶段策略**：先处理死代码（删除），再处理过度暴露的 API（降级为私有）。

### Phase 1: 删除死代码

对全项目无调用的函数/方法直接删除：

1. `tool_def` 包中 `Tool` 的 `is_node_program`、`is_rust_program`、`is_java_program`、`is_kotlin_builtin_tool`（4个，全项目无任何调用）
2. `utils` 包中的 `default` 函数（全项目无调用）

删除后需同步清理对应的测试（如有）和注释。

### Phase 2: 降级过度暴露的 API

将仅包内使用的 `pub` 函数改为私有（移除 `pub` 关键字）：

**高优先级（命令包 - 外部只使用 `get_command` 和 `run`）：**
- `command` 包：`get_cmd_and_args`, `join_args`, 以及所有 `run_*` 命令执行函数、`download_file`, `extract_file`, `get_arg_value` 等

**中优先级（基础设施包）：**
- `utils` 包：`styled`, `to_debug_string`, `show_to_string`, `array_to_string`
- `log` 包：`enter_alternate_screen_on_release_mode`, `exit_alternate_screen_on_release_mode`, `set_log_level`, `clear_lines`, `add_log_lines_by_content`, `LogLevel::from_string`, `LogLevel::to_int`
- `checksum` 包：`compute_file_sha256`
- `progress` 包：`progress_bar_with_detailed_info`, `clear_progress`
- `fs_ext` 包：`Path` 结构体、`copy_dir`

**低优先级（工具定义包 - 部分可能预留扩展用途）：**
- `tool_def` 包：`Tool::from_string_with_option_result`、`tools_dir`（被 `tool_dir` 内部调用）、`format_os_compat_error`（被 node/bun/zig/go 内部调用）、`installed_versions`（包内使用）

### Phase 3: 验证

每个阶段完成后执行 `moon check` 和 `moon test` 确保无编译错误和测试失败。最终重新生成所有 `pkg.generated.mbti` 文件。

## Key Design Decisions

1. **为何不删除 `command` 包的 `run_*` 函数而是降级为私有？**
   - 这些函数虽仅被 `run()` 内部调度调用，但它们是独立的命令执行逻辑，保留为包内私有函数有利于代码组织和后续维护。直接删除会破坏 `run()` 的调度逻辑。

2. **为何对 `tool_def` 包的部分函数标记为"低优先级"？**
   - `Tool::from_string_with_option_result` 虽目前仅包内测试使用，但作为 `from_string` 的安全变体（返回 Option 而非 raise），可能对外部使用者有价值。降级为私有但不删除。

3. **为何按优先级分阶段？**
   - 命令包（`command`）是变更最集中的区域，降级最多函数，优先处理可快速验证整体策略可行性。基础设施包影响范围较小但更关键，需更谨慎处理。

## Risks / Trade-offs

- **风险**：mvm 如果作为库被其他项目依赖，移除 `pub` 会破坏其公共 API。但 mvm 是独立 CLI 工具，无外部库消费者，此风险可忽略。
- **风险**：部分被降级的函数可能在未来需要外部访问（如 `from_string_with_option_result`）。重新加回 `pub` 是低成本操作。
- **权衡**：`command` 包的 `run_*` 函数降级为私有后，`run.mbt` 中 `run()` 函数仍可正常调度它们（MoonBit 包内函数天然可见）。但这也意味着无法从外部直接调用某个命令（如测试中直接调用 `run_install`），不过当前无此类外部调用需求。