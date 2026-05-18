## 1. 删除 tool_def 包中的死代码

- [x] 1.1 删除 `Tool::is_java_program` 方法及其测试代码（`cmd/tools/tool_def/tool.mbt`）
- [x] 1.2 删除 `Tool::is_kotlin_builtin_tool` 方法及其测试代码（`cmd/tools/tool_def/tool.mbt`）
- [x] 1.3 删除 `Tool::is_node_program` 方法及其测试代码（`cmd/tools/tool_def/tool.mbt`）
- [x] 1.4 删除 `Tool::is_rust_program` 方法及其测试代码（`cmd/tools/tool_def/tool.mbt`）
- [x] 1.5 运行 `moon check` 验证 tool_def 包编译无错误
- [x] 1.6 执行 `moon info` 重新生成 `cmd/tools/tool_def/pkg.generated.mbti`

## 2. 降级 command 包的过度暴露 API

- [x] 2.1 将 `get_cmd_and_args` 移除 `pub` 关键字（`command/cmd.mbt`）
- [x] 2.2 将 `join_args` 移除 `pub` 关键字（`command/cmd.mbt`）
- [x] 2.3 将 `run_help` 移除 `pub` 关键字（`cmd/command/help.mbt`）
- [x] 2.4 将 `run_version` 移除 `pub` 关键字（`cmd/command/version.mbt`）
- [x] 2.5 将 `run_upgrade` 和 `run_upgrade_list` 移除 `pub` 关键字（`cmd/command/upgrade.mbt`）
- [x] 2.6 将 `run_setup` 移除 `pub` 关键字（`cmd/command/setup.mbt`）
- [x] 2.7 将 `run_install` 移除 `pub` 关键字（`cmd/command/install.mbt`）
- [x] 2.8 将 `run_pin` 移除 `pub` 关键字（`cmd/command/pin.mbt`）
- [x] 2.9 将 `run_use` 移除 `pub` 关键字（`cmd/command/use.mbt`）
- [x] 2.10 将 `run_unuse` 移除 `pub` 关键字（`cmd/command/unuse.mbt`）
- [x] 2.11 将 `run_list` 移除 `pub` 关键字（`cmd/command/list.mbt`）
- [x] 2.12 将 `run_uninstall` 移除 `pub` 关键字（`cmd/command/uninstall.mbt`）
- [x] 2.13 将 `run_which` 移除 `pub` 关键字（`cmd/command/which.mbt`）
- [x] 2.14 将 `run_current` 移除 `pub` 关键字（`cmd/command/current.mbt`）
- [x] 2.15 将 `run_run` 移除 `pub` 关键字（`cmd/command/run_run.mbt`）
- [x] 2.16 将 `run_cache_clean` 移除 `pub` 关键字（`cmd/command/cache_clean.mbt`）
- [x] 2.17 将 `run_config`, `run_config_set`, `run_config_preset` 移除 `pub` 关键字（`cmd/command/config.mbt`）
- [x] 2.18 将 `download_file` 移除 `pub` 关键字（`cmd/command/install.mbt`）
- [x] 2.19 将 `extract_file` 移除 `pub` 关键字（`cmd/command/install.mbt`）
- [x] 2.20 将 `get_arg_value` 移除 `pub` 关键字（`cmd/command/command.mbt`）
- [x] 2.21 运行 `moon check` 验证 command 包编译无错误
- [x] 2.22 执行 `moon info` 重新生成 command 相关包的 `pkg.generated.mbti`

## 3. 降级 utils 包的过度暴露 API

- [x] 3.1 将 `styled` 移除 `pub` 关键字（`utils/color.mbt`）
- [x] 3.2 删除 `to_debug_string` 函数（无任何调用，直接删除而非降级）
- [x] 3.3 删除 `show_to_string` 函数（无任何调用，直接删除而非降级）
- [x] 3.4 删除 `array_to_string` 函数（无任何调用，直接删除而非降级）
- [x] 3.5 运行 `moon check` 验证 utils 包编译无错误
- [x] 3.6 执行 `moon info` 重新生成 `utils/pkg.generated.mbti`

## 4. 降级 log 包的过度暴露 API

- [x] 4.1 将 `enter_alternate_screen_on_release_mode` 移除 `pub` 关键字（`log/log.mbt`）
- [x] 4.2 将 `exit_alternate_screen_on_release_mode` 移除 `pub` 关键字（`log/log.mbt`）
- [x] 4.3 将 `set_log_level` 移除 `pub` 关键字（`log/log_level.mbt`）
- [x] 4.4 将 `clear_lines` 移除 `pub` 关键字（`log/log.mbt`）
- [x] 4.5 将 `add_log_lines_by_content` 移除 `pub` 关键字（`log/log.mbt`）
- [x] 4.6 将 `LogLevel::from_string` 移除 `pub` 关键字（`log/log_level.mbt`）
- [x] 4.7 将 `LogLevel::to_int` 移除 `pub` 关键字（`log/log_level.mbt`）
- [x] 4.8 运行 `moon check` 验证 log 包编译无错误
- [x] 4.9 执行 `moon info` 重新生成 `log/pkg.generated.mbti`

## 5. 降级其他包的过度暴露 API

- [x] 5.1 将 `checksum.compute_file_sha256` 移除 `pub` 关键字（`checksum/checksum.mbt`）
- [x] 5.2 将 `progress.progress_bar_with_detailed_info` 移除 `pub` 关键字（`progress/progress.mbt`）
- [x] 5.3 将 `progress.clear_progress` 移除 `pub` 关键字（`progress/progress.mbt`）
- [x] 5.4 将 `fs_ext.Path` 结构体移除 `pub` 关键字（`fs_ext/path.mbt`）
- [x] 5.5 将 `fs_ext.copy_dir` 移除 `pub` 关键字（`fs_ext/file.mbt`）
- [x] 5.6 将 `tool_def.Tool::from_string_with_option_result` 移除 `pub` 关键字（`cmd/tools/tool_def/tool.mbt`）
- [x] 5.7 将 `tool_def.tools_dir` 移除 `pub` 关键字（`cmd/tools/tool_def/tool.mbt`）
- [x] 5.8 将 `tool_def.format_os_compat_error` 移除 `pub` 关键字（`cmd/tools/tool_def/tool.mbt`）
- [x] 5.9 将 `tool_def.installed_versions` 移除 `pub` 关键字（`cmd/tools/tool_def/tool.mbt`）
- [x] 5.10 运行 `moon check` 验证所有相关包编译无错误
- [x] 5.11 执行 `moon info` 重新生成 checksum/progress/fs_ext/tool_def 的 `pkg.generated.mbti`

## 6. 最终验证与清理

- [x] 6.1 运行 `moon test` 验证所有测试通过（92/93 通过，1 个环境相关失败）
- [x] 6.2 执行 `moon info` 重新生成所有受影响包的 `pkg.generated.mbti` 文件
- [x] 6.3 检查各 `pkg.generated.mbti` 文件是否不再包含已删除/降级的函数声明
- [x] 6.4 运行 `moon build` 认构建成功（0 错误）
