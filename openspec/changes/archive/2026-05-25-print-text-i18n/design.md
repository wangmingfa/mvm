## Context

mvm 是一个基于 MoonBit 的多语言版本管理器，当前所有面向用户的文本（帮助信息、命令提示、错误消息、日志输出、进度提示）均以中文字符串硬编码在源代码中。涉及的模块包括：
- `cmd/command/` — 所有子命令（help、install、use、pin、current、which、list、config、setup、upgrade、cache_clean、unuse、uninstall、run、version）
- `log/` — 日志模块（info、warn、error、success 消息）
- `progress/` — 进度条提示文本（如"解压"）
- `cmd/tools/tool_def/config.mbt` — 配置相关错误消息

现有架构中，用户面向文本通过 `print_to(result, msg)` 输出到 `CommandResult`，日志文本通过 `@log.info/warn/error/success(msg)` 输出。两者都直接传入硬编码字符串。

## Goals / Non-Goals

**Goals:**
1. 创建 `i18n` 包，提供翻译键查找机制
2. 内置支持中文简体（zh-CN）和美式英文（en-US），翻译字典嵌入 .mbt 文件中
3. 支持扩展语言：通过 JSON 文件加载外部语言，JSON 文件放在可执行文件同目录下
4. 将所有 `print_to` 和 `@log` 调用中的硬编码文本替换为 i18n 键查找
5. 在 `GlobalConfig` 中增加 `language` 字段，允许用户手动设置语言
6. 默认语言为美式英文（en-US），国际化工具默认使用英文更合理
7. 所有 i18n 键调用的代码上方添加一行中文注释，描述该键的文本含义
8. 开发脚本（debug/run）自动将项目根目录 `langs/` 文件夹复制到 exe 目录
9. 新增 `mvm lang` 命令，将指定语言 JSON 文件复制到 exe 同目录，方便扩展语言

**Non-Goals:**
1. 不实现完整的翻译管理工具或翻译文件热加载
2. 不支持运行时语言切换（需重启命令生效）
3. 不翻译日志的 debug 消息（仅面向开发者，保持英文）
4. 不翻译代码注释和函数名（这些属于开发者面向内容）
5. 不重构 `print_to` 或 `@log` 的调用机制（仅替换字符串内容）
6. 不内置除 zh-CN 和 en-US 外的其他语言（扩展语言通过 JSON 文件实现）

## Architecture

### 新增 `i18n` 包

位于 `i18n/` 目录，包含以下文件：

```
i18n/
  moon.pkg          — 包定义，导出 i18n API
  i18n.mbt          — 核心翻译查找逻辑（内置字典查找 + JSON 外部字典加载）
  zh.mbt            — 中文简体翻译字典（内置）
  en.mbt            — 美式英文翻译字典（内置）
```

### 项目根目录 `langs/` 文件夹

存放扩展语言的 JSON 文件，开发时放在项目根目录，运行时需要复制到 exe 同目录：

```
langs/
  ja.json           — 日语翻译文件示例
  fr.json           — 法语翻译文件示例
  ko.json           — 韩语翻译文件示例
  ...                — 其他扩展语言
```

JSON 文件格式与内置字典键名一致：
```json
{
  "help.usage": "使い方:",
  "help.command": "コマンド:",
  "install.already_installed": "{tool}@{version} は既にインストールされています",
  ...
}
```

### 翻译键设计

采用**层级式键名**，格式为 `{模块}.{类别}.{键}`，例如：
- `help.usage` — "用法:" / "Usage:"
- `help.command` — "命令:" / "Commands:"
- `install.already_installed` — "{tool}@{version} 已安装" / "{tool}@{version} is already installed"
- `config.not_set` — "(未设置)" / "(not set)"
- `error.sha256_failed` — "SHA256 校验失败！文件可能已损坏或被篡改" / "SHA256 verification failed! File may be corrupted or tampered"
- `log.cancelled` — "操作已取消" / "Operation cancelled"

### 核心 API

```moonbit
/// i18n.mbt

/// 语言类型
pub enum Lang {
  Zh  // 中文简体 (zh-CN)
  En  // 美式英文 (en-US)
} derive(Show, Eq)

/// 获取当前语言（从 GlobalConfig 读取，未配置时从系统环境变量推断）
pub fn current_lang() -> Lang

/// 获取所有可用语言列表（内置 + 外部 JSON）
pub fn available_langs() -> Array[Lang]

/// 翻译函数：按键查找当前语言的文本
/// 查找顺序：1. 外部 JSON 字典  2. 内置字典  3. 英文 fallback  4. 返回键本身
pub fn t(key : String) -> String

/// 翻译函数：带参数插值
pub fn t(key : String, args : Map[String, String]) -> String
```

### 翻译查找优先级

当用户通过 `mvm config set language xxx` 设置语言后，翻译查找顺序为：

1. **外部 JSON 字典**：从可执行文件同目录读取 `{lang}.json`（如 `ja.json`）
2. **内置字典**：zh.mbt 或 en.mbt 中的翻译
3. **英文 fallback**：如果当前语言字典中找不到键，回退到 en.mbt
4. **键本身 fallback**：如果英文字典也找不到，返回键字符串本身

```
查找流程:
  用户设置 language=ja
  → 尝试读取 exe 同目录的 ja.json
  → 找到则用 ja.json 查找 key
  → ja.json 中 key 不存在 → 查找内置 en_dict
  → en_dict 中也不存在 → 返回 key 本身
  → ja.json 文件不存在 → 直接使用内置 en_dict（回退到英文）
```

### 代码注释规范

每个 i18n 键调用的上方，必须添加一行中文注释描述该键的文本含义，方便开发者理解：

```moonbit
// 用法提示
print_to(result, @i18n.t("help.usage"))
// 命令列表标题
print_to(result, @i18n.t("help.command"))
// {tool}@{version} 已安装
@log.warn(@i18n.t("install.already_installed", { "tool": tool.to_string(), "version": version }))
```

### 翻译字典结构

```moonbit
// zh.mbt — 中文简体（内置）
let zh_dict : Map[String, String] = {
  "help.usage": "用法:",
  "help.command": "命令:",
  "help.option": "选项:",
  "help.example": "示例:",
  "install.already_installed": "{tool}@{version} 已安装",
  "config.not_set": "(未设置)",
  ...
}

// en.mbt — 美式英文（内置）
let en_dict : Map[String, String] = {
  "help.usage": "Usage:",
  "help.command": "Commands:",
  "help.option": "Options:",
  "help.example": "Examples:",
  "install.already_installed": "{tool}@{version} is already installed",
  "config.not_set": "(not set)",
  ...
}
```

### 插值机制

翻译文本中使用 `{变量名}` 作为占位符，`t(key, args)` 函数会将 `args` 中的值替换对应占位符：

```moonbit
// {tool}@{version} 已安装
print_to(result, @i18n.t("install.already_installed", { "tool": tool.to_string(), "version": version }))
// 中文输出: "node@v20 已安装"
// 英文输出: "node@v20 is already installed"
```

### 语言配置

在 `GlobalConfig` 中新增 `language` 字段：

```moonbit
pub(all) struct GlobalConfig {
  github_proxy : String?
  node_mirror : String?
  go_mirror : String?
  python_mirror : String?
  rust_mirror : String?
  java_mirror : String?
  language : String?  // 新增: "zh"、"en" 或扩展语言代码如 "ja"
} derive(FromJson, ToJson)
```

`i18n::current_lang()` 的语言优先级：
1. `GlobalConfig.language`（用户显式设置，支持任意语言代码）
2. 系统环境变量 `LANG` / `LC_ALL`（自动推断，仅映射到内置 zh/en）
3. 默认值 `En`（美式英文）

### 使用方式变更

调用从硬编码字符串改为 i18n 函数调用，且上方添加中文注释：

```moonbit
// 之前
print_to(result, "用法:")
print_to(result, "命令:")
@log.warn("SHA256 校验失败！文件可能已损坏或被篡改")

// 之后
// 用法提示
print_to(result, @i18n.t("help.usage"))
// 命令列表标题
print_to(result, @i18n.t("help.command"))
// SHA256 校验失败！文件可能已损坏或被篡改
@log.warn(@i18n.t("error.sha256_failed"))
```

对于带参数的文本：

```moonbit
// 之前
print_to(result, "\{tool}@\{version} 已安装")

// 之后
// {tool}@{version} 已安装
print_to(result, @i18n.t("install.already_installed", { "tool": tool.to_string(), "version": version }))
```

### 配置命令扩展

`mvm config set` 支持 `language` 键，接受任意语言代码：

```moonbit
mvm config set language zh    // 设置中文简体（内置）
mvm config set language en    // 设置美式英文（内置）
mvm config set language ja    // 设置日语（需 ja.json 在 exe 同目录）
```

当设置扩展语言但找不到对应 JSON 文件时，运行命令自动回退到英文。

### `mvm lang` 命令

新增 `mvm lang` 命令，用于将语言 JSON 文件复制到 exe 同目录，方便扩展语言：

```moonbit
mvm lang install ja                            // 将 langs/ja.json 复制到 exe 同目录
mvm lang install ja fr ko                      // 同时复制多个语言文件
mvm lang install ja /path/to/ja.json           // 从绝对路径复制
mvm lang install ja ./ja.json                  // 从相对路径复制
mvm lang install ja ja.json                    // 从相对路径复制（同目录下查找）
mvm lang list                                  // 列出所有可用语言（内置 + 已安装的外部语言）
mvm lang remove ja                             // 从 exe 同目录移除语言文件
```

`mvm lang install` 的文件查找逻辑：
1. 如果指定了第二个参数（路径），从该路径复制源文件
   - 绝对路径：直接使用（如 `/path/to/ja.json`）
   - 相对路径：基于当前工作目录解析（如 `./ja.json` 或 `ja.json`）
2. 如果未指定路径，从项目 MVM_HOME 目录下的 `langs/` 文件夹查找 `{lang}.json`
3. 复制到可执行文件同目录，目标文件名为 `{lang}.json`

### 开发脚本修改

修改 `scripts/debug.sh`、`scripts/run.sh`、`scripts/debug.ps1`、`scripts/run.ps1`，在运行前自动将项目根目录的 `langs/` 文件夹复制到 exe 目录：

```bash
# sh 脚本中添加
if [ -d "langs" ]; then
  cp -r langs/* "$target_dir/" 2>/dev/null || true
fi
```

```powershell
# ps1 脚本中添加
if (Test-Path "langs") {
  Copy-Item -Path "langs\*" -Destination $targetDir -Force -ErrorAction SilentlyContinue
}
```

## Risks / Trade-offs

1. **翻译键数量大**：当前硬编码文本约有 90+ 处 `print_to` 调用和大量 `@log` 消息，翻译键总量可能在 200+。需要系统化地提取所有文本，遗漏会导致某些场景仍显示中文。

2. **插值复杂度**：部分文本包含多个动态变量和复杂的字符串拼接（如 `help.mbt` 中的表格格式化），需要仔细设计插值方式，避免翻译键过于碎片化。

3. **`GlobalConfig` 序列化兼容性**：新增 `language` 字段是 `String?`（可选），现有 JSON 配置文件中缺少此字段时 `FromJson` 会默认为 `None`，保持向后兼容。

4. **日志消息的双重性**：`@log` 的 debug 源码位置信息（如 `loc` 参数）不属于翻译范畴；但 `@log.warn/error/success` 中的用户面向文本需要翻译。需要区分哪些日志消息面向用户、哪些面向开发者。

5. **帮助文本的排版**：`help.mbt` 使用动态计算列宽对齐，翻译后英文文本长度与中文不同，可能影响对齐效果。需要验证英文帮助信息的排版是否仍然美观。

6. **性能影响**：每次翻译查找都是 Map 查询，对于 CLI 工具来说性能开销可忽略不计。内置字典在模块初始化时加载；外部 JSON 字典仅在��次查找时读取并缓存。

7. **外部 JSON 文件安全性**：从 exe 同目录读取 JSON 文件，需验证 JSON 格式正确性和文件完整性，避免恶意或损坏的翻译文件导致程序异常。

8. **扩展语言回退机制**：当设置了非内置语言（如 ja）但找不到对应 JSON 文件时，回退到英文（即默认语言），符合国际通用惯例。

9. **默认语言为英文的影响**：现有中文用户首次运行时将看到英文界面，需要通过 `mvm config set language zh` 切换到中文。在 README 中应明确说明此配置步骤。
