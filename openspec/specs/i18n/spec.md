# i18n 国际化规范

## 翻译查找机制

i18n 包提供翻译键查找机制，支持内置字典和外部 JSON 字典，按优先级查找文本。

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为中文简体（内置）
- **THEN** 返回 `"用法:"`

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为美式英文（内置）
- **THEN** 返回 `"Usage:"`

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为日语（ja，外部 JSON 存在）
- **THEN** 从 MVM_HOME/langs 目录的 `ja.json` 加载字典并返回 `"使い方:"`

- **WHEN** 调用 `@i18n.t("nonexistent.key")` 且键不存在于任何字典
- **THEN** 返回键本身 `"nonexistent.key"` 作为最终 fallback

- **WHEN** 键在当前语言字典中不存在，但存在于英文内置字典中
- **THEN** 回退到英文字典查找并返回英文文本

## 翻译查找优先级

翻译查找按以下优先级依次尝试：

- **WHEN** 当前语言为非内置语言（如 ja）
- **THEN** 查找顺序为：1. 外部 JSON 字典（MVM_HOME/langs 的 `{lang}.json`）→ 2. 内置 en_dict → 3. 返回键本身

- **WHEN** 当前语言为内置语言（zh 或 en）
- **THEN** 查找顺序为：1. 内置字典（zh_dict 或 en_dict）→ 2. 内置 en_dict → 3. 返回键本身

- **WHEN** 当前语言为扩展语言但外部 JSON 文件不存在
- **THEN** 跳过外部字典查找，直接回退到内置 en_dict（回退到英文）

## 外部 JSON 字典加载

i18n 包支持从 MVM_HOME/langs 目录加载外部语言 JSON 文件。

- **WHEN** 当前语言为 "ja" 且 MVM_HOME/langs 存在 `ja.json`
- **THEN** 读取并解析 JSON 文件为 `Map[String, String]`，作为外部翻译字典

- **WHEN** 外部 JSON 文件格式无效（不是合法 JSON 或不是 String->String 映射）
- **THEN** 忽略该文件，回退到内置字典，输出 warn 日志提示 JSON 解析失败

- **WHEN** 外部 JSON 字典首次加载后
- **THEN** 缓存到内存中，后续查找不再重复读取文件（同一命令执行周期内缓存有效）

## 参数插值

翻译文本支持 `{变量名}` 占位符，通过 `t(key, args)` 进行动态替换。

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node", "version": "v20" })` 且当前语言为中文
- **THEN** 返回 `"node@v20 已安装"`

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node", "version": "v20" })` 且当前语言为英文
- **THEN** 返回 `"node@v20 is already installed"`

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node" })` 且缺少 `version` 参数
- **THEN** 占位符 `{version}` 保留原样不被替换（不删除也不替换为空字符串）

## 语言类型定义

定义 `Lang` 枚举类型表示内置语言，扩展语言通过字符串代码标识。

- **WHEN** 定义 `Lang` 枚举
- **THEN** 包含 `Zh`（中文简体 zh-CN）和 `En`（美式英文 en-US）两个变体，derive `Show` 和 `Eq`

- **WHEN** `Lang::Zh` 转为字符串
- **THEN** 返回 `"zh"`

- **WHEN** `Lang::En` 转为字符串
- **THEN** 返回 `"en"`

- **WHEN** 字符串 `"zh"` 转为 `Lang`
- **THEN** 返回 `Lang::Zh`

- **WHEN** 字符串 `"en"` 转为 `Lang`
- **THEN** 返回 `Lang::En`

- **WHEN** 字符串 `"ja"`（扩展语言）转为 `Lang`
- **THEN** 返回 `Lang::En`（内置枚举仅包含 zh/en，扩展语言通过字符串标识，查找时使用外部 JSON）

- **WHEN** 调用 `available_langs()`
- **THEN** 返回内置语言列表 `[Zh, En]`（不包含外部 JSON 语言，因为外部语言是动态的）

## GlobalConfig 增加 language 字段

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

## 语言优先级判定

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

## config 命令支持 language 键

`mvm config set` 命令支持设置 `language` 配置项，接受任意语言代码字符串。

- **WHEN** 执行 `mvm config set language en`
- **THEN** `GlobalConfig.language` 设为 `Some("en")`，配置文件更新，输出提示设置成功

- **WHEN** 执行 `mvm config set language zh`
- **THEN** `GlobalConfig.language` 设为 `Some("zh")`，配置文件更新，输出提示设置成功

- **WHEN** 执行 `mvm config set language ja`（扩展语言）
- **THEN** `GlobalConfig.language` 设为 `Some("ja")`，配置文件更新，输出提示设置成功（不做可用性校验，运行时按需加载）

- **WHEN** `mvm config list` 显示配置
- **THEN** 包含 `language` 字段，显示当前语言或"(未设置)"

## mvm lang 命令

### mvm lang set 命令

新增 `mvm lang set` 子命令，设置当前语言（等同 `mvm config set language`，但允许任意语言代码）。

- **WHEN** 执行 `mvm lang set zh`
- **THEN** `GlobalConfig.language` 设为 `Some("zh")`，i18n 立即生效，输出提示语言已设置

- **WHEN** 执行 `mvm lang set en`
- **THEN** `GlobalConfig.language` 设为 `Some("en")`，i18n 立即生效

- **WHEN** 执行 `mvm lang set ja`（扩展语言）
- **THEN** `GlobalConfig.language` 设为 `Some("ja")`，i18n 立即生效

### mvm lang install 命令

新增 `mvm lang install` 子命令，将语言 JSON 文件复制到 MVM_HOME/langs 并加载。

- **WHEN** 执行 `mvm lang install /path/to/ja.json`
- **THEN** 复制到 MVM_HOME/langs/ja.json，加载外部字典，输出安装信息

- **WHEN** 内置语言不允许安装覆盖（zh/zh-CN/en/en-US）
- **THEN** 输出错误提示"不能覆盖内置语言"

### mvm lang list 命令

新增 `mvm lang list` 子命令，列出所有可用语言。

- **WHEN** 执行 `mvm lang list`
- **THEN** 显示内置语言（zh: 中文简体, en: 美式英文）和已安装的外部语言（从 MVM_HOME/langs 目录检测）

- **WHEN** MVM_HOME/langs 存在 `ja.json`
- **THEN** `mvm lang list` 输出中包含 "ja" 标记为外部语言

### mvm lang remove 命令

新增 `mvm lang remove` 子命令，从 MVM_HOME/langs 移除语言文件。

- **WHEN** 执行 `mvm lang remove ja`
- **THEN** 从 MVM_HOME/langs 删除 `ja.json`，清除缓存，输出提示已移除

- **WHEN** 尝试移除内置语言（zh 或 en）
- **THEN** 输出提示"内置语言无法移除"

## 翻译字典完整性校验

中文和英文内置翻译字典必须包含相同的键集合，确保无遗漏。

- **WHEN** 对 `zh_dict` 和 `en_dict` 的键集合做差集运算
- **THEN** 差集应为空（两个字典键完全一致）

## 代码注释规范

所有 i18n 键调用的上方，必须添加一行中文注释描述该键的文本含义。

- **WHEN** 编写 `@i18n.t("help.usage")` 调用
- **THEN** 该行上方必须有一行注释如 `// 用法提示`

- **WHEN** 编写 `@i18n.t("install.already_installed", args)` 调用
- **THEN** 该行上方必须有一行注释如 `// {tool}@{version} 已安装`

## 翻译键命名规范

翻译键必须遵循层级命名规范。

- **WHEN** 定义新的翻译键
- **THEN** 格式为 `{模块}.{类别}.{具体键名}`，使用 snake_case，如 `install.already_installed`、`config.not_set`

- **WHEN** 翻译键对应的文本包含动态变量
- **THEN** 使用 `{变量名}` 占位符，变量名使用 snake_case，如 `{tool}`、`{version}`、`{path}`

## 扩展语言 JSON 文件格式

扩展语言通过 JSON 文件实现，放在 MVM_HOME/langs 目录下，文件名为 `{lang_code}.json`。

- **WHEN** 创建日语扩展语言文件 `ja.json`
- **THEN** JSON 格式为键值对映射，键名与内置字典键名完全一致

- **WHEN** JSON 文件中的键与内置字典键不一致
- **THEN** 缺失的键在查找时回退到内置英文字典，多余的键被忽略

- **WHEN** JSON 文件中包含 `{变量名}` 占位符
- **THEN** 插值机制与内置字典一致，`t(key, args)` 正常替换
