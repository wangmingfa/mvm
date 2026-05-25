## 1. i18n 包基础设施

- [x] 1.1 创建 `i18n/` 目录和 `moon.pkg` 文件，定义包导出
- [x] 1.2 创建 `i18n/i18n.mbt`，实现 `Lang` 枚举（Zh/En）、`to_string`/`from_string` 转换、`current_lang()` 语言优先级判定逻辑
- [x] 1.3 实现 `t(key)` 翻译查找函数：按优先级查找（内置字典 → en fallback → 键本身）
- [x] 1.4 实现 `t(key, args)` 参数插值函数：`{变量名}` 占位符替换，缺失参数保留原样
- [x] 1.5 实现外部 JSON 字典加载机制：从 exe 同目录读取 `{lang}.json`，解析为 Map，缓存到内存
- [x] 1.6 实现扩展语言回退逻辑：JSON 文件不存在时回退到内置英文字典
- [x] 1.7 在 `moon.mod.json` 中注册 `i18n` 包路径
- [x] 1.8 编写 i18n 核心逻辑的单元测试（查找、插值、fallback、JSON 加载、Lang 转换）

## 2. 翻译字典（内置 zh-CN 和 en-US）

- [x] 2.1 创建 `i18n/zh.mbt`，包含所有中文简体翻译键值对（按 specs/i18n-dictionaries.md 定义）
- [x] 2.2 创建 `i18n/en.mbt`，包含所有美式英文翻译键值对（键集合与 zh.mbt 完全一致）
- [x] 2.3 编写字典完整性校验测试（验证 zh_dict 和 en_dict 键集合一致）
- [x] 2.4 创建项目根目录 `langs/` 文件夹，添加示例 `ja.json` 用于开发测试

## 3. GlobalConfig 语言配置

- [x] 3.1 在 `GlobalConfig` 结构中新增 `language : String?` 字段，更新 `derive(FromJson, ToJson)`
- [x] 3.2 更新 `make_global_config` 函数，新增 `language?` 参数，保持覆盖逻辑
- [x] 3.3 更新 `GlobalConfig::to_string` 方法，增加 `language` 字段输出
- [x] 3.4 修改 `@i18n.current_lang()` 实现：优先读 GlobalConfig.language → 系统环境变量 → 默认 en
- [x] 3.5 更新 `GlobalConfig` 相关单元测试（FromJson/ToJson/make_global_config 覆盖逻辑）

## 4. config 命令扩展

- [x] 4.1 在 `cmd/command/config.mbt` 的 `run_config_list` 中增加 `language` 配置显示
- [x] 4.2 在 `cmd/command/config.mbt` 的 `run_config_set` 中增加 `language` 键处理分支，接受任意语言代码字符串
- [x] 4.3 在 config set language 的输出提示中使用 i18n 键，上方添加中文注释

## 5. mvm lang 命令

- [x] 5.1 创建 `cmd/command/lang.mbt`，实现 `run_lang_install` 子命令：将指定语言 JSON 文件复制到 exe 同目录
- [x] 5.2 实现 `run_lang_install` 的多语言同时安装（如 `mvm lang install ja fr ko`）
- [x] 5.3 实现路径参数：支持 `mvm lang install ja /path/to/ja.json`（绝对路径）和 `mvm lang install ja ./ja.json`（相对路径），未指定路径时从 MVM_HOME 的 `langs/` 查找
- [x] 5.4 实现 `run_lang_list` 子命令：列出内置语言 + 已安装的外部语言（检测 exe 同目录的 JSON 文件）
- [x] 5.5 实现 `run_lang_remove` 子命令：从 exe 同目录删除语言 JSON 文件，禁止移除内置语言
- [x] 5.6 在 `cmd/command/command.mbt` 中注册 `lang` 子命令
- [x] 5.7 在 `cmd/command/moon.pkg` 中确保 `@fs_ext` 导入可用
- [x] 5.8 在 lang 命令的所有 i18n 调用上方添加中文注释

## 6. 命令文件文本替换（面向用户输出，每个键上方添加中文注释）

- [x] 6.1 在 `cmd/command/moon.pkg` 中添加 `username/mvm/i18n` 导入
- [x] 6.2 替换 `cmd/command/help.mbt` 中所有硬编码中文文本为 `@i18n.t()` 调用，上方添加中文注释
- [x] 6.3 替换 `cmd/command/install.mbt` 中所有面向用户的日志文本为 i18n 调用，上方添加中文注释
- [x] 6.4 替换 `cmd/command/config.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.5 替换 `cmd/command/setup.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.6 替换 `cmd/command/current.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.7 替换 `cmd/command/which.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.8 替换 `cmd/command/list.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.9 替换 `cmd/command/upgrade.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.10 替换 `cmd/command/cache_clean.mbt` 中所有硬编码中文文本为 i18n 调用，上方添加中文注释
- [x] 6.11 替换 `cmd/command/use.mbt` 中面向用户的文本为 i18n 调用，上方添加中文注释
- [x] 6.12 替换 `cmd/command/pin.mbt` 中面向用户的文本为 i18n 调用，上方添加中文注释
- [x] 6.13 替换 `cmd/command/unuse.mbt` 中面向用户的文本为 i18n 调用，上方添加中文注释
- [x] 6.14 替换 `cmd/command/uninstall.mbt` 中面向用户的文本为 i18n 调用，上方添加中文注释
- [x] 6.15 替换 `cmd/command/run_run.mbt` 中面向用户的文本为 i18n 调用，上方添加中文注释
- [x] 6.16 替换 `cmd/command/version.mbt` 中面向用户的文本为 i18n 调用（如有）

## 7. log 模块文本替换

- [x] 7.1 在 `log/moon.pkg` 中添加 `username/mvm/i18n` 导入（采用 setter 模式替代，避免潜在循环依赖）
- [x] 7.2 替换 `log/log.mbt` 中 `println_error` 的 `"操作已取消"` 为 `@i18n.t("log.cancelled")`，上方添加中文注释（通过 `set_cancelled_text()` setter 在 main.mbt 中动态设置）

## 8. 工具模块错误消息替换

- [x] 8.1 在 `cmd/tools/moon.pkg` 和 `cmd/tools/tool_def/moon.pkg` 中添加 `username/mvm/i18n` 导入
- [x] 8.2 替换 `cmd/tools/tool_def/config.mbt` 中所有 `raise fail(...)` 的中文错误消息为 i18n 调用，上方添加中文注释

## 9. progress 模块文本替换

- [x] 9.1 在 `progress/moon.pkg` 中添加 `username/mvm/i18n` 导入
- [x] 9.2 替换 `install.mbt` 中进度条前缀 `"解压"` 为 `@i18n.t("install.extract_prefix")`，上方添加中文注释（前缀由命令文件传入，progress 模块本身无需修改）

## 10. 测试与验证

- [x] 10.1 运行 `moon check` 验证所有模块编译无误（0 errors, 0 warnings）
- [x] 10.2 运行 `moon test` 确保所有测试通过（137/137 passed）
- [ ] 10.3 手动测试 `mvm --help` 的中英文输出（设置 `language=zh` 和 `language=en`）
- [ ] 10.4 手动测试 `mvm config list` 和 `mvm config set language` 命令
- [ ] 10.5 手动测试 `mvm lang install ja`、`mvm lang list`、`mvm lang remove ja` 命令
- [ ] 10.6 手动测试扩展语言回退：设置 `language=ja` 但无 ja.json 时输出英文
