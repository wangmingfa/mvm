## CHANGED Requirements

### Requirement: tool.mbt 职责拆分

`tool_def/tool.mbt` 按职责拆分为多个文件，降低单文件复杂度。

#### Scenario: Tool 枚举和基础路径保留在 tool.mbt
- **WHEN** 查看 `tool_def/tool.mbt`
- **THEN** 仅包含 Tool 枚举定义、Show/Eq 实现、from_string/from_string_with_option_result、mvm_home/mvm_bin_home/tools_dir/tool_dir/version_dir/is_installed/installed_versions、ToolExe 结构及其构造函数、format_os_compat_error

#### Scenario: 配置管理逻辑迁移到 config.mbt
- **WHEN** 查看 `tool_def/config.mbt`
- **THEN** 包含 Config/GlobalConfig 结构、make_global_config、get_config/write_config/write_project_config/write_global_config/remove_global_config/save_global_config/get_global_config、get_node_version_from_volta_package_json、CONFIG_FILE/VOLTA_CONFIG_FILE/GLOBAL_SETTINGS_FILE 常量

#### Scenario: URL 替换逻辑迁移到 url.mbt
- **WHEN** 查看 `tool_def/url.mbt`
- **THEN** 包含 UrlReplaceContext 结构、replace_url、apply_global_config、NODE_RELEASE_URL/GO_RELEASE_URL 常量引用

#### Scenario: 缓存逻辑迁移到 cache.mbt
- **WHEN** 查看 `tool_def/cache.mbt`
- **THEN** 包含 cache_dir/temp_dir、no_cache_flag/set_no_cache_mode/is_no_cache_mode、read_cache_file_content/write_cache_file_content、get_target_version_with_cache

#### Scenario: 拆分后包对外 API 不变
- **WHEN** 其他包通过 `@tool_def` 引用 Tool、GlobalConfig、UrlReplaceContext 等类型和函数
- **THEN** 所有 pub 函数和类型仍可通过 `@tool_def` 正常访问，无需修改调用方代码

### Requirement: download.mbt 重复代码合并

`request/download.mbt` 中 `get_file_size_with_curl` 和 `get_file_size_with_curl_exe` 合并为通用函数。

#### Scenario: 提取通用命令获取文件大小函数
- **WHEN** 查看 `request/download.mbt`
- **THEN** 存在 `fn get_file_size_by_command(cmd_name : String, url : String) -> Int64?` 通用函数
- **THEN** 该函数接收命令名作为参数，执行 `{cmd_name} -sI {url}` 并解析 Content-Length

#### Scenario: curl.exe 获取文件大小使用通用函数
- **WHEN** 调用 `get_file_size_with_curl_exe(url)`
- **THEN** 内部调用 `get_file_size_by_command("curl.exe", url)`
- **THEN** 失败时 fallback 到 `get_file_size_with_powershell(url)`（保持原有行为）

#### Scenario: curl 获取文件大小使用通用函数
- **WHEN** 调用 `get_file_size_with_curl(url)`
- **THEN** 内部调用 `get_file_size_by_command("curl", url)`
- **THEN** 失败时返回 None（保持原有行为）
