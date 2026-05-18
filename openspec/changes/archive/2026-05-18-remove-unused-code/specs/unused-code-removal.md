## REMOVED Requirements

### Requirement: 死代码函数应从项目中删除

以下函数在全项目（包括定义包和所有外部包）中均无任何调用，应完全删除：

| 包 | 函数/方法 |
|---|-----------|
| `cmd/tools/tool_def` | `Tool::is_java_program` |
| `cmd/tools/tool_def` | `Tool::is_kotlin_builtin_tool` |
| `cmd/tools/tool_def` | `Tool::is_node_program` |
| `cmd/tools/tool_def` | `Tool::is_rust_program` |

> **保留项**：`utils.default` 虽当前无调用，但预留使用不删除。

> **注意**：`pkg.generated.mbti` 已过时，方法名与代码实际不一致（如 mbti 中 `is_java_builtin_tools` 对应代码中 `is_java_program`）。以上使用代码中的实际方法名。

- **Scenario: 删除后项目编译正常**
  - **WHEN** 删除上述所有函数及其对应的测试代码
  - **THEN** `moon check` 编译通过，无错误

- **Scenario: 删除后项目测试正常**
  - **WHEN** 删除上述所有函数及其对应的测试代码
  - **THEN** `moon test` 全部测试通过

- **Scenario: pkg.generated.mbti 不包含已删除的函数**
  - **WHEN** 执行 `moon info` 重新生成各包的 `pkg.generated.mbti`
  - **THEN** 对应包的 `pkg.generated.mbti` 不包含上述已删除函数的声明

### Requirement: 仅包内使用的 pub 函数应降级为私有

以下 `pub` 函数仅在定义包内被调用（无外部 `@包名.函数` 形式的调用），应移除 `pub` 关键字：

**command 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `get_cmd_and_args` | `command_exists`, `run` |
| `join_args` | `get_cmd_and_args`, `run` |
| `run_help` | `run()` |
| `run_version` | `run()` |
| `run_upgrade` | `run()` |
| `run_upgrade_list` | `run()` |
| `run_setup` | `run()` |
| `run_install` | `run()` |
| `run_pin` | `run()` |
| `run_use` | `run()` |
| `run_unuse` | `run()` |
| `run_list` | `run()` |
| `run_uninstall` | `run()` |
| `run_which` | `run()` |
| `run_current` | `run()` |
| `run_run` | `run()` |
| `run_cache_clean` | `run()` |
| `run_config` | `run()` |
| `run_config_set` | `run()` |
| `run_config_preset` | `run()` |
| `download_file` | `install.mbt` 内部 |
| `extract_file` | `install.mbt` 内部 |
| `get_arg_value` | 包内使用 |

**utils 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `styled` | `print_logo()` |
| `to_debug_string` | 无（仅定义未使用） |
| `show_to_string` | 无（仅定义未使用） |
| `array_to_string` | 无（仅定义未使用） |

**log 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `enter_alternate_screen_on_release_mode` | 仅测试内使用 |
| `exit_alternate_screen_on_release_mode` | 仅测试内使用 |
| `set_log_level` | 仅包内使用 |
| `clear_lines` | 仅包内使用 |
| `add_log_lines_by_content` | 仅包内使用 |
| `LogLevel::from_string` | 仅包内 `from_string_with_default` 使用 |
| `LogLevel::to_int` | 仅包内使用 |

**checksum 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `compute_file_sha256` | `verify_file_checksum` 内部调用 |

**progress 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `progress_bar_with_detailed_info` | 仅包内使用 |
| `clear_progress` | 仅包内使用 |

**fs_ext 包：**
| 函数/类型 | 内部调用位置 |
|-----------|-------------|
| `Path` 结构体 | 仅包内使用 |
| `copy_dir` | 仅包内使用 |

**tool_def 包：**
| 函数 | 内部调用位置 |
|------|-------------|
| `Tool::from_string_with_option_result` | 仅包内测试使用 |
| `tools_dir` | `tool_dir()` 内部调用 |
| `format_os_compat_error` | node/bun/zig/go 内部调用 |
| `installed_versions` | 仅包内使用 |

- **Scenario: 降级后包内调用正常**
  - **WHEN** 将上述函数的 `pub` 关键字移除
  - **THEN** 包内代码仍可正常调用这些函数（MoonBit 包内函数天然可见）

- **Scenario: 降级后外部无法访问**
  - **WHEN** 将上述函数的 `pub` 关键字移除
  - **THEN** 包外代码尝试调用这些函数时编译报错（符合预期，因为当前无外部调用）

- **Scenario: 降级后项目编译和测试正常**
  - **WHEN** 将上述函数的 `pub` 关键字移除
  - **THEN** `moon check` 和 `moon test` 均通过

- **Scenario: pkg.generated.mbti 不包含降级后的函数**
  - **WHEN** 执行 `moon info` 重新生成各包的 `pkg.generated.mbti`
  - **THEN** 降级为私有的函数不再出现在 `pkg.generated.mbti` 中

## ADDED Requirements

### Requirement: pkg.generated.mbti 文件应与实际公共接口一致

- **Scenario: 重新生成后接口文件准确**
  - **WHEN** 完成所有死代码删除和 pub 降级操作后，执行 `moon info` 重新生成所有 `pkg.generated.mbti`
  - **THEN** 每个 `pkg.generated.mbti` 中声明的函数/类型均对应实际仍保持 `pub` 的接口，无多余声明

### Requirement: 原有功能不受影响

- **Scenario: 所有原有测试通过**
  - **WHEN** 完成所有变更后执行 `moon test`
  - **THEN** 所有原有测试仍通过（包内测试可访问私有函数）

- **Scenario: CLI 命令功能完整**
  - **WHEN** 完成所有变更后构建并运行 mvm
  - **THEN** 所有 CLI 命令（help, version, install, use, list, uninstall, upgrade, etc.）功能正常