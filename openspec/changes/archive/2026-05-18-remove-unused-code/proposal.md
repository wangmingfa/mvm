## Why

项目经过多次迭代后，积累了大量未被使用的代码，包括：
1. **完全死代码**：从未在任何地方被调用的函数/方法
2. **过度暴露的公共 API**：标记为 `pub` 但仅在包内使用的函数，应改为私有以减少包的公开接口面积
3. **未使用的类型/结构体**：导出但从未被外部引用的类型

这些未使用代码增加了维护负担、混淆了包的公共接口意图，并可能误导新开发者认为这些 API 是项目核心功能的一部分。清理它们可以：
- 减小包的公开接口面积，使 API 更清晰
- 减少维护成本，避免为无用代码添加注释或处理兼容性问题
- 提升代码可读性和项目整洁度

## What

### 死代码（完全未使用，应删除）

| 包 | 函数/方法 | 状态 |
|---|-----------|------|
| `cmd/tools/tool_def` | `Tool::is_java_program` | 全项目无调用 |
| `cmd/tools/tool_def` | `Tool::is_kotlin_builtin_tool` | 全项目无调用 |
| `cmd/tools/tool_def` | `Tool::is_node_program` | 全项目无调用 |
| `cmd/tools/tool_def` | `Tool::is_rust_program` | 全项目无调用 |

> **保留项**：`utils.default` 虽当前无调用，但预留使用不删除。

> **注意**：`pkg.generated.mbti` 文件中的方法名与代码实际定义不一致（如 mbti 中 `is_java_builtin_tools` 对应代码中 `is_java_program`），说明 mbti 文件已过时。以上列表使用代码中实际的方法名。

### 过度暴露的公共 API（仅包内使用，应改为私有）

| 包 | 函数/类型 | 内部使用情况 |
|---|-----------|-------------|
| `command` | `get_cmd_and_args` | 仅 `run()` 内部使用 |
| `command` | `join_args` | 仅包内使用 |
| `command` | `run_help`, `run_version`, `run_upgrade`, `run_upgrade_list`, `run_setup`, `run_install`, `run_pin`, `run_use`, `run_unuse`, `run_list`, `run_uninstall`, `run_which`, `run_current`, `run_run`, `run_cache_clean`, `run_config`, `run_config_set`, `run_config_preset` | 仅被 `run()` 调度调用 |
| `command` | `download_file`, `extract_file`, `get_arg_value` | 仅包内使用 |
| `utils` | `styled` | 仅 `print_logo()` 内部使用 |
| `utils` | `to_debug_string`, `show_to_string`, `array_to_string` | 无外部调用 |
| `log` | `enter_alternate_screen_on_release_mode`, `exit_alternate_screen_on_release_mode` | 仅测试内使用 |
| `log` | `set_log_level`, `clear_lines`, `add_log_lines_by_content` | 无外部调用 |
| `log` | `LogLevel::from_string`, `LogLevel::to_int` | 仅包内使用 |
| `checksum` | `compute_file_sha256` | 仅 `verify_file_checksum` 内部使用 |
| `progress` | `progress_bar_with_detailed_info`, `clear_progress` | 无外部调用 |
| `fs_ext` | `Path` 结构体 | 无外部调用 |
| `fs_ext` | `copy_dir` | 无外部调用 |
| `tool_def` | `Tool::from_string_with_option_result` | 仅包内测试使用 |
| `tool_def` | `tools_dir` | 仅 `tool_dir()` 内部使用 |
| `tool_def` | `format_os_compat_error` | node/bun/zig/go 内部使用 |
| `tool_def` | `installed_versions` | 仅包内使用 |

## Impact

- **代码变更范围**：涉及 `utils`, `command`, `log`, `checksum`, `progress`, `fs_ext`, `cmd/tools/tool_def` 等多个包
- **公共 API 变化**：部分函数从 `pub` 变为私有，可能影响依赖此包的外部项目（但 mvm 是独立 CLI 工具，无外部消费者）
- **安全性**：所有变更均为删除未使用代码或将 `pub` 改为私有，不影响任何实际运行功能
- **测试影响**：部分函数仅在包内测试中使用（如 `from_string_with_option_result`），降级为私有后测试仍可正常运行（MoonBit 中包内测试可访问私有函数）