## ADDED Requirements

### Requirement: 命令文本翻译键覆盖

翻译字典必须覆盖所有命令文件中面向用户的硬编码文本。以下为各模块的翻译键清单：

#### help 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `help.title` | `mvm (Multi Version Manager) {VERSION} —— One Tool to Manage Them All` | `mvm (Multi Version Manager) {VERSION} — One Tool to Manage Them All` |
| `help.usage` | `用法:` | `Usage:` |
| `help.usage_detail` | `mvm <命令> [参数]` | `mvm <command> [args]` |
| `help.commands` | `命令:` | `Commands:` |
| `help.options` | `选项:` | `Options:` |
| `help.examples` | `示例:` | `Examples:` |
| `help.cmd_install` | `安装指定版本` | `Install a specific version` |
| `help.cmd_use` | `设置全局版本` | `Set global version` |
| `help.cmd_pin` | `项目级版本锁定` | `Pin version for project` |
| `help.cmd_uninstall` | `卸载指定版本` | `Uninstall a specific version` |
| `help.cmd_list` | `查看已安装版本` | `List installed versions` |
| `help.cmd_current` | `查看当前使用版本` | `Show current version in use` |
| `help.cmd_which` | `查看工具路径` | `Show tool executable path` |
| `help.cmd_run` | `临时运行指定版本` | `Run with a specific version temporarily` |
| `help.cmd_unuse` | `移除全局版本设置` | `Remove global version setting` |
| `help.cmd_setup` | `初始化工具脚本和PATH` | `Initialize tool scripts and PATH` |
| `help.cmd_upgrade` | `升级 mvm 自身` | `Upgrade mvm itself` |
| `help.cmd_cache_clean` | `清理缓存` | `Clean cache` |
| `help.cmd_config` | `查看/设置配置` | `View/set configuration` |
| `help.opt_help` | `显示帮助信息` | `Show help information` |
| `help.opt_version` | `显示版本号` | `Show version number` |
| `help.opt_skip_verify` | `跳过 SHA256 校验（安装时使用）` | `Skip SHA256 verification (for install)` |
| `help.opt_no_cache` | `不使用缓存，强制重新下载（安装时使用）` | `Do not use cache, force re-download (for install)` |
| `help.opt_reinstall` | `重新安装当前版本（升级时使用）` | `Reinstall current version (for upgrade)` |

#### install 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `install.already_installed` | `{tool}@{version} 已安装` | `{tool}@{version} is already installed` |
| `install.installing` | `安装 {tool} {version}` | `Installing {tool} {version}` |
| `install.no_download_url` | `无法获取下载地址` | `Cannot get download URL` |
| `install.unsupported_os` | `不支持的操作系统` | `Unsupported operating system` |
| `install.downloading` | `正在下载: {url}` | `Downloading: {url}` |
| `install.saving_to` | `保存到：{dest}` | `Saving to: {dest}` |
| `install.fallback_native` | `HTTP 客户端下载失败，尝试使用系统原生命令下载...` | `HTTP client download failed, trying native command download...` |
| `install.cached_archive` | `发现已缓存的压缩包，直接复用: {path}` | `Found cached archive, reusing: {path}` |
| `install.skip_download` | `跳过下载` | `Skipping download` |
| `install.start_download` | `开始下载` | `Starting download` |
| `install.skip_verify` | `已跳过 SHA256 校验（使用了 --skip-verify 参数）` | `SHA256 verification skipped (--skip-verify flag used)` |
| `install.verifying` | `正在校验 SHA256 ...` | `Verifying SHA256 ...` |
| `install.verify_failed` | `SHA256 校验失败！文件可能已损坏或被篡改` | `SHA256 verification failed! File may be corrupted or tampered` |
| `install.retry_download` | `正在重新下载（不使用缓存/续传）...` | `Re-downloading (without cache/resumption)...` |
| `install.retry_failed` | `重新下载后校验仍然失败，请检查网络或代理配置，或使用 --skip-verify 跳过校验` | `Verification still failed after re-download. Check network/proxy config, or use --skip-verify` |
| `install.verify_passed` | `SHA256 校验通过` | `SHA256 verification passed` |
| `install.no_checksum` | `{tool} 不支持 SHA256 校验，跳过校验继续安装` | `{tool} does not support SHA256 verification, skipping` |
| `install.extracting` | `正在解压 {file} 到 {dest} ...` | `Extracting {file} to {dest} ...` |
| `install.unknown_format` | `未知的压缩格式：{file}` | `Unknown archive format: {file}` |
| `install.extract_failed` | `解压失败，原因：{reason}` | `Extraction failed: {reason}` |
| `install.extract_prefix` | `解压` | `Extracting` |
| `install.install_success` | `{tool} {version} 安装成功` | `{tool} {version} installed successfully` |

#### config 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `config.title` | `MVM 配置:` | `MVM Configuration:` |
| `config.global_path` | `全局配置文件: {path}` | `Global config file: {path}` |
| `config.github_proxy` | `GitHub 代理配置:` | `GitHub proxy configuration:` |
| `config.node_mirror` | `Node 镜像配置:` | `Node mirror configuration:` |
| `config.go_mirror` | `Go 镜像配置:` | `Go mirror configuration:` |
| `config.python_mirror` | `Python 镜像配置:` | `Python mirror configuration:` |
| `config.rust_mirror` | `Rust 镜像配置:` | `Rust mirror configuration:` |
| `config.java_mirror` | `Java 镜像配置:` | `Java mirror configuration:` |
| `config.language` | `语言配置:` | `Language configuration:` |
| `config.not_set` | `(未设置)` | `(not set)` |
| `config.saved_to` | `配置已保存到: {path}` | `Configuration saved to: {path}` |
| `config.set_value` | `设置 {key} = {value}` | `Set {key} = {value}` |
| `config.preset_applied` | `已应用快速配置:` | `Quick configuration applied:` |
| `config.lang_set` | `语言已设置为 {lang}` | `Language set to {lang}` |

#### setup 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `setup.install_complete` | `安装完成！可执行文件已安装到 {dir}` | `Installation complete! Executables installed to {dir}` |
| `setup.main_command` | `主命令` | `Main command` |
| `setup.npm_pkg_dir` | `npm 全局包安装路径：{dir}` | `npm global package install path: {dir}` |
| `setup.tool_symlinks` | `工具软连接：{tools}` | `Tool symlinks: {tools}` |
| `setup.tool_scripts` | `工具脚本：{tools}` | `Tool scripts: {tools}` |
| `setup.restart_hint` | `如果 mvm 命令无效，请重启终端或执行：` | `If mvm command is not working, restart terminal or run:` |
| `setup.source_command` | `source {path}` | `source {path}` |

#### current 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `current.not_set` | `(未设置)` | `(not set)` |
| `current.not_installed` | `未安装` | `not installed` |

#### which 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `which.not_installed` | `未安装` | `not installed` |
| `which.install_hint` | `请使用 mvm install {tool}@{version} 安装该版本` | `Use mvm install {tool}@{version} to install this version` |

#### list 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `list.no_versions` | `(暂无)` | `(none)` |

#### upgrade 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `upgrade.current_marker` | `← 当前版本` | `← current` |

#### cache_clean 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `cache.cleaned_cache` | `已清理缓存目录: {dir}` | `Cache directory cleaned: {dir}` |
| `cache.cleaned_temp` | `已清理临时目录: {dir}` | `Temp directory cleaned: {dir}` |
| `cache.empty` | `缓存目录为空，无需清理` | `Cache directory is empty, no need to clean` |

#### lang 模块

| 键 | 中文 | 英文 |
|---|------|------|
| `lang.install_success` | `语言文件 {lang}.json 已安装到 {dir}` | `Language file {lang}.json installed to {dir}` |
| `lang.install_multi` | `语言文件 {langs} 已安装到 {dir}` | `Language files {langs} installed to {dir}` |
| `lang.file_not_found` | `语言文件 {lang}.json 不存在` | `Language file {lang}.json not found` |
| `lang.remove_success` | `语言文件 {lang}.json 已移除` | `Language file {lang}.json removed` |
| `lang.remove_not_found` | `语言文件 {lang}.json 不存在，无需移除` | `Language file {lang}.json not found, no need to remove` |
| `lang.remove_builtin` | `内置语言 {lang} 无法移除` | `Built-in language {lang} cannot be removed` |
| `lang.list_title` | `可用语言:` | `Available languages:` |
| `lang.list_builtin` | `{lang}: {name} (内置)` | `{lang}: {name} (built-in)` |
| `lang.list_external` | `{lang}: (外部语言)` | `{lang}: (external)` |

#### log 模块（用户面向）

| 键 | 中文 | 英文 |
|---|------|------|
| `log.cancelled` | `操作已取消` | `Operation cancelled` |

#### 错误消息

| 键 | 中文 | 英文 |
|---|------|------|
| `error.invalid_json` | `文件 {path} 不是有效的json格式` | `File {path} is not valid JSON` |
| `error.invalid_format` | `文件 {path} 格式无效` | `File {path} has invalid format` |
| `error.no_global_version` | `{tool} 未设置全局版本` | `{tool} has no global version set` |
| `error.global_version_remove_failed` | `文件 {path} 格式不对` | `File {path} has incorrect format` |

### Requirement: 翻译键命名规范

翻译键必须遵循层级命名规范。

- **WHEN** 定义新的翻译键
- **THEN** 格式为 `{模块}.{类别}.{具体键名}`，使用 snake_case，如 `install.already_installed`、`config.not_set`

- **WHEN** 翻译键对应的文本包含动态变量
- **THEN** 使用 `{变量名}` 占位符，变量名使用 snake_case，如 `{tool}`、`{version}`、`{path}`

### Requirement: 扩展语言 JSON 文件格式

扩展语言通过 JSON 文件实现，放在可执行文件同目录下，文件名为 `{lang_code}.json`。

- **WHEN** 创建日语扩展语言文件 `ja.json`
- **THEN** JSON 格式为键值对映射，键名与内置字典键名完全一致：
```json
{
  "help.usage": "使い方:",
  "help.command": "コマンド:",
  "help.option": "オプション:",
  "help.example": "例:",
  "install.already_installed": "{tool}@{version} は既にインストールされています",
  "config.not_set": "(未設定)",
  ...
}
```

- **WHEN** JSON 文件中的键与内置字典键不一致
- **THEN** 缺失的键在查找时回退到内置英文字典，多余的键被忽略

- **WHEN** JSON 文件中包含 `{变量名}` 占位符
- **THEN** 插值机制与内置字典一致，`t(key, args)` 正常替换

### Requirement: langs 目录结构

项目根目录的 `langs/` 文件夹存放开发时的扩展语言 JSON 文件。

- **WHEN** 开发者创建新的扩展语言
- **THEN** 将 JSON 文件放在项目根目录 `langs/` 下，文件名格式为 `{lang_code}.json`

- **WHEN** 开发脚本（debug/run）执行时
- **THEN** 自动将 `langs/` 文件夹内容复制到 exe 目标目录，确保开发时语言文件可用

- **WHEN** 用户通过 `mvm lang install ja` 安装扩展语言
- **THEN** 从 MVM_HOME 下的 `langs/` 或指定 `--source` 路径复制到 exe 同目录

## MODIFIED Requirements

### Requirement: config.unsupported_lang 修改为 config.lang_set

原 `config.unsupported_lang` 约束（仅允许 zh/en）不再适用。`mvm config set language` 现在接受任意语言代码字符串，不再校验语言是否可用。运行时按需加载外部 JSON，找不到则回退到英文。

- **WHEN** 执行 `mvm config set language ja`
- **THEN** 直接设置 `language` 为 `"ja"`，不做可用性校验，输出 `config.lang_set` 提示

## REMOVED Requirements

### Requirement: config.unsupported_lang（已移除）

原约束"不支持的语言: {lang}，仅支持 zh/en"已被移除，因为现在支持任意语言代码，通过外部 JSON 扩展。
