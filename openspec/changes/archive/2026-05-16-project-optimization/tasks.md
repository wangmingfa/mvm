## 1. 代码重构：tool.mbt 职责拆分

- [x] 1.1 创建 `tool_def/cache.mbt`，迁移缓存相关代码（cache_dir、temp_dir、no_cache_flag、set_no_cache_mode、is_no_cache_mode、read_cache_file_content、write_cache_file_content、get_target_version_with_cache）
- [x] 1.2 创建 `tool_def/config.mbt`，迁移配置管理代码（Config/GlobalConfig 结构、make_global_config、get_config、write_config、write_project_config、write_global_config、remove_global_config、save_global_config、get_global_config、get_node_version_from_volta_package_json、CONFIG_FILE/VOLTA_CONFIG_FILE/GLOBAL_SETTINGS_FILE 常量及相关测试）
- [x] 1.3 创建 `tool_def/url.mbt`，迁移 URL 相关代码（UrlReplaceContext、replace_url、apply_global_config 及相关测试）
- [x] 1.4 从 `tool.mbt` 中删除已迁移的代码，保留 Tool 枚举、基础路径函数、ToolExe 结构、format_os_compat_error
- [x] 1.5 更新 `tool_def/moon.pkg`，确保包内 `using` 引用正确（确认无需修改）
- [x] 1.6 更新 `cmd/tools/common.mbt` 的 `pub using @tool_def` 声明，确保所有 pub 符号仍可引用（确认无需修改）
- [x] 1.7 运行 `moon info && moon fmt` 更新接口和格式化代码
- [x] 1.8 运行 `moon test` 确认所有测试通过，检查 `.mbti` diff 确认对外接口不变

## 2. 代码去重：download.mbt 重复逻辑合并

- [x] 2.1 提取通用函数 `get_file_size_by_command(cmd_name : String, url : String) -> Int64?`，统一 curl/curl.exe 的文件大小获取逻辑
- [x] 2.2 修改 `get_file_size_with_curl_exe` 调用 `get_file_size_by_command("curl.exe", url)`，失败时 fallback 到 PowerShell
- [x] 2.3 修改 `get_file_size_with_curl` 调用 `get_file_size_by_command("curl", url)`，失败时返回 None
- [x] 2.4 为 `parse_content_length_from_headers` 编写单元测试（验证解析 Content-Length 的逻辑）
- [x] 2.5 运行 `moon test` 确认下载相关测试通过（72 tests passed）

## 3. 错误处理统一

- [x] 3.1 审查 `cmd/command/install.mbt`，将 `@log.error() + return` 中应中断的错误改为 `raise fail()`（如"无法获取下载地址"、"解压失败"）
- [x] 3.2 审查 `cmd/command/run_run.mbt`，将 `@log.error() + return` 中应中断的错误改为 `raise fail()`（如"可执行文件不存在"）
- [x] 3.3 审查其他命令文件（use、unuse、which、list、current 等），统一错误处理模式
- [x] 3.4 确认版本已安装等"提示但不中断"的场景保持 `@log.warn() + return` 不变

## 4. 下载重试机制

- [x] 4.1 在 `download.mbt` 的 `download` 函数中添加网络重试逻辑：最多 3 次，间隔 1s → 3s → 5s
- [x] 4.2 仅对连接失败/超时类错误重试，不对 HTTP 4xx/5xx 错误重试
- [x] 4.3 每次重试前输出 `@log.warn("下载失败，第 N 次重试...")`
- [x] 4.4 在 `download_by_native_command` 中增加失败时的 warn 日志

## 5. 配置输入校验

- [x] 5.1 在 `cmd/command/config.mbt` 的 `run_config_set` 中添加 URL 格式校验函数 `validate_config_url`
- [x] 5.2 校验逻辑：URL 类值必须以 `http://` 或 `https://` 开头（严格，不通过则 raise fail）
- [x] 5.3 校验逻辑：`github_proxy` 值应包含 `$URL` 变量（宽松，缺少则 warn 但不阻断）
- [x] 5.4 预设配置（如 `config set china`）不触发校验
- [x] 5.5 为 URL 校验函数编写单元测试

## 6. 项目元数据补全

- [x] 6.1 更新 `moon.mod.json` 的 `description` 字段为 "Multi Version Manager - One tool to manage Node.js, Bun, Zig, Go versions"
- [x] 6.2 更新 `moon.mod.json` 的 `keywords` 字段为 ["mvm", "version-manager", "node", "bun", "zig", "go"]
- [x] 6.3 同步更新中文 README.md 和英文 README_en.md 中的项目描述（如有不一致）——两个 README 描述一致，无需修改

## 7. 测试覆盖补充

- [x] 7.1 为 `tool_def/url.mbt` 中的 `apply_global_config` 各分支编写测试（node_mirror、go_mirror、github_proxy、无配置、优先级）
- [x] 7.2 为 `tool_def/cache.mbt` 中的缓存读写逻辑编写测试（no_cache 模式、正常模式）
- [x] 7.3 为 `cmd/command/config.mbt` 的 URL 校验函数编写测试（已在 5.5 完成）
- [x] 7.4 运行 `moon test` 确认所有新增测试通过（83 tests passed）
- [x] 7.5 运行 `moon coverage analyze` 检查覆盖率情况——工具链在分析过程中崩溃，暂时跳过

## 8. 最终验证

- [x] 8.1 运行 `moon info && moon fmt` 确保接口和格式正确
- [x] 8.2 运行 `moon test` 确保所有测试通过（83 tests passed）
- [x] 8.3 检查 `.mbti` diff 确认对外包接口变更——`extract_file` Bool→Unit、`run_config_set` 加 raise 为有意设计变更；其他为可选参数扩展，向后兼容
- [x] 8.4 本地构建 `moon build --release` 认编译成功
