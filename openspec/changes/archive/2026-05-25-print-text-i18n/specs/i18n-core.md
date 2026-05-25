## ADDED Requirements

### Requirement: 翻译查找机制

i18n 包应提供翻译键查找机制，支持内置字典和外部 JSON 字典，按优先级查找文本。

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为中文简体（内置）
- **THEN** 返回 `"用法:"`

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为美式英文（内置）
- **THEN** 返回 `"Usage:"`

- **WHEN** 调用 `@i18n.t("help.usage")` 且当前语言为日语（ja，外部 JSON 存在）
- **THEN** 从 exe 同目录的 `ja.json` 加载字典并返回 `"使い方:"`

- **WHEN** 调用 `@i18n.t("nonexistent.key")` 且键不存在于任何字典
- **THEN** 返回键本身 `"nonexistent.key"` 作为最终 fallback

- **WHEN** 键在当前语言字典中不存在，但存在于英文内置字典中
- **THEN** 回退到英文字典查找并返回英文文本

### Requirement: 翻译查找优先级

翻译查找按以下优先级依次尝试：

- **WHEN** 当前语言为非内置语言（如 ja）
- **THEN** 查找顺序为：1. 外部 JSON 字典（exe 同目录的 `{lang}.json`）→ 2. 内置 en_dict → 3. 返回键本身

- **WHEN** 当前语言为内置语言（zh 或 en）
- **THEN** 查找顺序为：1. 内置字典（zh_dict 或 en_dict）→ 2. 内置 en_dict → 3. 返回键本身

- **WHEN** 当前语言为扩展语言但外部 JSON 文件不存在
- **THEN** 跳过外部字典查找，直接回退到内置 en_dict（回退到英文）

### Requirement: 外部 JSON 字典加载

i18n 包支持从可执行文件同目录加载外部语言 JSON 文件。

- **WHEN** 当前语言为 "ja" 且 exe 同目录存在 `ja.json`
- **THEN** 读取并解析 JSON 文件为 `Map[String, String]`，作为外部翻译字典

- **WHEN** 外部 JSON 文件格式无效（不是合法 JSON 或不是 String->String 映射）
- **THEN** 忽略该文件，回退到内置字典，输出 warn 日志提示 JSON 解析失败

- **WHEN** 外部 JSON 字典首次加载后
- **THEN** 缓存到内存中，后续查找不再重复读取文件（同一命令执行周期内缓存有效）

### Requirement: 参数插值

翻译文本支持 `{变量名}` 占位符，通过 `t(key, args)` 进行动态替换。

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node", "version": "v20" })` 且当前语言为中文
- **THEN** 返回 `"node@v20 已安装"`

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node", "version": "v20" })` 且当前语言为英文
- **THEN** 返回 `"node@v20 is already installed"`

- **WHEN** 调用 `@i18n.t("install.already_installed", { "tool": "node" })` 且缺少 `version` 参数
- **THEN** 占位符 `{version}` 保留原样不被替换（不删除也不替换为空字符串）

### Requirement: 语言类型定义

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

### Requirement: 代码注释规范

所有 i18n 键调用的上方，必须添加一行中文注释描述该键的文本含义。

- **WHEN** 编写 `@i18n.t("help.usage")` 调用
- **THEN** 该行上方必须有一行注释如 `// 用法提示`

- **WHEN** 编写 `@i18n.t("install.already_installed", args)` 调用
- **THEN** 该行上方必须有一行注释如 `// {tool}@{version} 已安装`

- **WHEN** 注释内容为翻译键对应的中文文本（含占位符原样保留）
- **THEN** 方便开发者无需查字典即可理解该键的文本含义

### Requirement: 翻译字典完整性校验

中文和英文内置翻译字典必须包含相同的键集合，确保无遗漏。

- **WHEN** 对 `zh_dict` 和 `en_dict` 的键集合做差集运算
- **THEN** 差集应为空（两个字典键完全一致）

- **WHEN** `zh_dict` 包含某个键但 `en_dict` 缺少
- **THEN** `en_dict` 中该键的查找结果 fallback 为键本身

## MODIFIED Requirements

_无修改的现有需求_

## REMOVED Requirements

_无删除的现有需求_
