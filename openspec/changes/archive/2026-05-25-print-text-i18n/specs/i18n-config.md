## ADDED Requirements

### Requirement: GlobalConfig 增加 language 字段

`GlobalConfig` 结构新增可选的 `language` 字段，允许用户显式指定语言偏好，支持任意语言代码。

- **WHEN** `GlobalConfig` 的 JSON 包含 `"language": "en"` 字段
- **THEN** `FromJson` 解析后 `language` 为 `Some("en")`

- **WHEN** `GlobalConfig` 的 JSON 包含 `"language": "ja"` 字段（扩展语言）
- **THEN** `FromJson` 解析后 `language` 为 `Some("ja")`

- **WHEN** `GlobalConfig` 的 JSON 不包含 `language` 字段
- **THEN** `FromJson` 解析后 `language` 为 `None`（向后兼容）

- **WHEN** `GlobalConfig` 调用 `ToJson` 序列化且 `language` 为 `None`
- **THEN** JSON 中不包含 `language` 字段（保持配置文件简洁）

- **WHEN** `GlobalConfig` 调用 `ToJson` 序列化且 `language` 为 `Some("zh")`
- **THEN** JSON 中包含 `"language": "zh"` 字段

### Requirement: 语言优先级判定

`@i18n.current_lang()` 按以下优先级确定当前语言：

- **WHEN** `GlobalConfig.language` 为 `Some("en")`
- **THEN** `current_lang()` 返回 `Lang::En`（用户显式设置优先）

- **WHEN** `GlobalConfig.language` 为 `Some("zh")`
- **THEN** `current_lang()` 返回 `Lang::Zh`

- **WHEN** `GlobalConfig.language` 为 `Some("ja")`（扩展语言）
- **THEN** `current_lang()` 返回 `Lang::En` 作为内置枚举值，但翻译查找时使用字符串 `"ja"` 加载外部 JSON

- **WHEN** `GlobalConfig.language` 为 `None` 且系统环境变量 `LANG` 包含 `en` 或 `C`
- **THEN** `current_lang()` 返回 `Lang::En`

- **WHEN** `GlobalConfig.language` 为 `None` 且系统环境变量 `LANG` 包含 `zh` 或 `CN`
- **THEN** `current_lang()` 返回 `Lang::Zh`

- **WHEN** `GlobalConfig.language` 为 `None` 且无法推断系统语言
- **THEN** `current_lang()` 返回 `Lang::En`（默认美式英文）

### Requirement: config 命令支持 language 键

`mvm config set` 命令支持设置 `language` 配置项，接受任意语言代码字符串。

- **WHEN** 执行 `mvm config set language en`
- **THEN** `GlobalConfig.language` 设为 `Some("en")`，配置文件更新，输出提示设置成功

- **WHEN** 执行 `mvm config set language zh`
- **THEN** `GlobalConfig.language` 设为 `Some("zh")`，配置文件更新，输出提示设置成功

- **WHEN** 执行 `mvm config set language ja`（扩展语言）
- **THEN** `GlobalConfig.language` 设为 `Some("ja")`，配置文件更新，输出提示设置成功（不校验语言是否可用，运行时按需加载）

- **WHEN** `mvm config list` 显示配置
- **THEN** 包含 `language` 字段，显示当前语言或"(未设置)"

### Requirement: make_global_config 支持 language 参数

`make_global_config` 函数新增 `language` 参数。

- **WHEN** 调用 `make_global_config(language=Some("en"))`
- **THEN** 返回的 `GlobalConfig.language` 为 `Some("en")`

- **WHEN** 调用 `make_global_config(language=None)` 且 `existing_config.language` 为 `Some("zh")`
- **THEN** 返回的 `GlobalConfig.language` 为 `Some("zh")`（保留现有值）

### Requirement: mvm lang install 命令

新增 `mvm lang install` 子命令，将语言 JSON 文件复制到 exe 同目录。

- **WHEN** 执行 `mvm lang install ja`（未指定路径）
- **THEN** 从 MVM_HOME 下的 `langs/ja.json` 复制 `ja.json` 到 exe 同目录

- **WHEN** 执行 `mvm lang install ja fr ko`（未指定路径）
- **THEN** 同时复制 `ja.json`、`fr.json`、`ko.json` 到 exe 同目录

- **WHEN** 执行 `mvm lang install ja /path/to/ja.json`（绝对路径）
- **THEN** 从绝对路径 `/path/to/ja.json` 复制到 exe 同目录，目标文件名仍为 `ja.json`

- **WHEN** 执行 `mvm lang install ja ./ja.json`（相对路径）
- **THEN** 基于当前工作目录解析 `./ja.json`，复制到 exe 同目录

- **WHEN** 执行 `mvm lang install ja ja.json`（相对路径，无前缀）
- **THEN** 基于当前工作目录解析 `ja.json`，复制到 exe 同目录

- **WHEN** 源文件不存在（指定路径不存在，或 MVM_HOME 下 `langs/ja.json` 不存在）
- **THEN** 输出错误提示"语言文件 {lang}.json 不存在"，不执行复制

- **WHEN** 目标目录不存在
- **THEN** 自动创建目标目录后再复制

- **WHEN** 复制成功
- **THEN** 输出提示"语言文件 {lang}.json 已安装到 {exe_dir}"

### Requirement: mvm lang list 命令

新增 `mvm lang list` 子命令，列出所有可用语言。

- **WHEN** 执行 `mvm lang list`
- **THEN** 显示内置语言（zh: 中文简体, en: 美式英文）和已安装的外部语言（从 exe 同目录的 JSON 文件检测）

- **WHEN** exe 同目录存在 `ja.json`
- **THEN** `mvm lang list` 输出中包含 "ja: (外部语言)" 标记

- **WHEN** exe 同目录不存在任何额外 JSON 语言文件
- **THEN** `mvm lang list` 仅显示内置的 zh 和 en

### Requirement: mvm lang remove 命令

新增 `mvm lang remove` 子命令，从 exe 同目录移除语言文件。

- **WHEN** 执行 `mvm lang remove ja`
- **THEN** 从 exe 同目录删除 `ja.json`，输出提示"语言文件 ja.json 已移除"

- **WHEN** exe 同目录不存在 `ja.json`
- **THEN** 输出提示"语言文件 ja.json 不存在，无需移除"

- **WHEN** 尝试移除内置语言（zh 或 en）
- **THEN** 输出提示"内置语言 {lang} 无法移除"

### Requirement: 开发脚本自动复制 langs 目录

修改 `scripts/debug.sh`、`scripts/run.sh`、`scripts/debug.ps1`、`scripts/run.ps1`，在运行前自动将项目根目录 `langs/` 文件夹内容复制到 exe 目标目录。

- **WHEN** 执行 debug.sh 或 run.sh 且项目根目录存在 `langs/` 文件夹
- **THEN** 自动将 `langs/` 下所有文件复制到 exe 目标目录（覆盖已存在的同名文件）

- **WHEN** 执行 debug.ps1 或 run.ps1 且项目根目录存在 `langs/` 文件夹
- **THEN** 自动将 `langs/` 下所有文件复制到 exe 目标目录

- **WHEN** 项目根目录不存在 `langs/` 文件夹
- **THEN** 脚本不执行复制操作，正常运行

- **WHEN** 复制过程中出现错误（如权限问题）
- **THEN** 输出警告但不中断脚本执行（语言文件缺失不影响核心功能）

## MODIFIED Requirements

_无修改的现有需求_

## REMOVED Requirements

_无删除的现有需求_