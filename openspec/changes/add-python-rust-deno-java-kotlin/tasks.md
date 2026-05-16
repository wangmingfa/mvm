## 1. Tool 枚举与基础设施扩展

- [x] 1.1 在 `tool_def/tool.mbt` 的 `Tool` 枚举新增 Python、Rust、Cargo、Deno、Java、Javac、Jar、Kotlin、Kotlinc 变体
- [x] 1.2 更新 `Tool::to_str()` — 新增各变体的字符串映射
- [x] 1.3 更新 `Tool::from_string()` — 新增反向映射（"python" → Python 等）
- [x] 1.4 更新 `Tool::installable_tools()` — 新增 Python、Rust、Deno、Java、Kotlin
- [x] 1.5 更新 `Tool::all_tools()` — 新增所有变体（含 Cargo、Javac、Jar、Kotlinc）
- [x] 1.6 实现 `Tool::is_rust_builtin_tools()` — Cargo 为 true
- [x] 1.7 实现 `Tool::is_java_builtin_tools()` — Javac、Jar 为 true
- [x] 1.8 实现 `Tool::is_kotlin_builtin_tools()` — Kotlinc 为 true
- [x] 1.9 扩展 `Tool::get_belonging_tools()` — Cargo → Rust、Javac/Jar → Java、Kotlinc → Kotlin
- [x] 1.10 更新 `Tool::from_string` 测试 — 覆盖新变体和无效输入
- [x] 1.11 更新 `Eq for Tool` 实现 — 新增各变体的相等性判断

## 2. 通用分发层扩展

- [x] 2.1 在 `tools/common.mbt` 的 `get_target_version()` 新增 Python/Rust/Deno/Java/Kotlin 分支
- [x] 2.2 在 `get_expected_checksum()` 新增各语言校验分发分支
- [x] 2.3 在 `get_download_info()` 新增各语言下载信息分发分支
- [x] 2.4 在 `get_exe_path_for_version()` 新增各语言路径分发分支
- [x] 2.5 在 `match_version()` 新增 Python/Rust/Deno 的 "v" 前缀规则和 Java/Kotlin 的无前缀规则
- [x] 2.6 在 `get_tool_exe_path()` 支持 Rust/Java/Kotlin 内置工具查找逻辑
- [x] 2.7 在 `post_install()` 新增各语言的可执行文件权限设置列表
- [x] 2.8 更新 `common.mbt` 的 `using` 声明 — 引入新语言结构体类型

## 3. 配置体系扩展

- [x] 3.1 在 `tool_def/config.mbt` 的 `GlobalConfig` 新增 python_mirror、rust_mirror、java_mirror 字段（deno/kotlin 使用 github_proxy，无专属镜像）
- [x] 3.2 更新 `make_global_config()` — 新增 python/rust/java_mirror 参数
- [x] 3.3 更新 `GlobalConfig::to_string()` — 显示新增镜像字段
- [x] 3.4 更新 `get_global_config()` — 处理新增字段的默认值
- [x] 3.5 在 `Config`（mvm.json）新增 python、rust、deno、java、kotlin 字段
- [x] 3.6 更新 `Config::get_value()` — 支持新工具的配置获取
- [x] 3.7 更新 `Config::to_string()` — 显示新增语言字段
- [x] 3.8 扩展 `mvm config set china` — 一键配置所有新语言的国内镜像
- [x] 3.9 更新相关测试 — 覆盖新增字段的解析、序列化、覆盖逻辑

## 4. URL 替换扩展

- [x] 4.1 在 `tool_def/url.mbt` 定义各语言的基础 URL 常量（PYTHON_RELEASE_URL、RUST_RELEASE_URL、JAVA_RELEASE_URL 等）
- [x] 4.2 在 `apply_global_config()` 新增 python_mirror、rust_mirror、java_mirror 替换分支
- [x] 4.3 Deno/Kotlin 继续使用 github_proxy（无专属镜像）
- [x] 4.4 更新 URL 替换测试 — 覆盖新语言的镜像替换场景

## 5. Python 语言实现

- [x] 5.1 创建 `tool_def/python.mbt` — 实现 Python 结构体
- [x] 5.2 实现 `Python::get_target_version()` — 从 endoflife.date API 获取版本索引并解析
- [x] 5.3 实现 `Python::_get_proper_version()` — 支持 latest、主版本号、完整版本号匹配
- [x] 5.4 实现 `Python::get_download_info()` — 构造各平台下载 URL（tgz/zip）
- [x] 5.5 实现 `Python::get_expected_checksum()` — 从 python.org 获取 SHA256
- [x] 5.6 实现 `Python::get_exe_path()` — 返回 python3/python.exe 的绝对路径
- [x] 5.7 编写 Python 版本解析测试
- [x] 5.8 编写 Python 下载信息测试

## 6. Rust 语言实现

- [x] 6.1 创建 `tool_def/rust.mbt` — 实现 Rust 结构体
- [x] 6.2 实现 `Rust::get_target_version()` — 从 rust-lang.org TOML manifest 获取版本索引
- [x] 6.3 实现 `Rust::_get_proper_version()` — 支持 stable/nightly/beta 通道标签和版本号匹配
- [x] 6.4 实现 TOML manifest 解析逻辑（提取版本号和平台信息）
- [x] 6.5 实现 `Rust::get_download_info()` — 构造各平台下载 URL（使用目标三元组格式）
- [x] 6.6 实现 `Rust::get_expected_checksum()` — 从 manifest 中提取 sha256
- [x] 6.7 实现 `Rust::get_exe_path()` — 返回 rustc 的绝对路径
- [x] 6.8 实现 `Rust::get_rust_builtin_tool_path_and_version()` — Cargo 内置工具查找
- [x] 6.9 编写 Rust 版本解析测试（覆盖 stable/nightly/beta 通道）
- [x] 6.10 编写 Rust 下载信息测试

## 7. Deno 语言实现

- [x] 7.1 创建 `tool_def/deno.mbt` — 实现 Deno 结构体
- [x] 7.2 实现 `Deno::get_target_version()` — 从 GitHub releases API 获取版本索引
- [x] 7.3 实现 `Deno::_get_proper_version()` — 支持 latest 和版本号匹配
- [x] 7.4 实现 `Deno::get_download_info()` — 构造各平台下载 URL（root_path_depth=0）
- [x] 7.5 实现 `Deno::get_expected_checksum()` — 返回 None（无官方校验）
- [x] 7.6 实现 `Deno::get_exe_path()` — 返回 deno/deno.exe 的绝对路径（无 bin 子目录）
- [x] 7.7 编写 Deno 版本解析测试
- [x] 7.8 编写 Deno 下载信息测试

## 8. Java (JDK) 语言实现

- [x] 8.1 创建 `tool_def/java.mbt` — 实现 Java 结构体
- [x] 8.2 实现 `Java::get_target_version()` — 从 Adoptium API 获取版本索引
- [x] 8.3 实现 `Java::_get_proper_version()` — 支持 LTS 标签、latest、版本号匹配
- [x] 8.4 实现 `Java::get_download_info()` — 构造各平台 JDK 下载 URL
- [x] 8.5 实现 `Java::get_expected_checksum()` — 从 Adoptium release assets 获取 SHA256
- [x] 8.6 实现 `Java::get_exe_path()` — 返回 java/java.exe 的绝对路径
- [x] 8.7 实现 `Java::get_java_builtin_tool_path_and_version()` — javac/jar 内置工具查找
- [x] 8.8 编写 Java 版本解析测试（覆盖 LTS 8/11/17/21）
- [x] 8.9 编写 Java 下载信息测试

## 9. Kotlin 语言实现

- [x] 9.1 创建 `tool_def/kotlin.mbt` — 实现 Kotlin 结构体
- [x] 9.2 实现 `Kotlin::get_target_version()` — 从 GitHub releases API 获取版本索引
- [x] 9.3 实现 `Kotlin::_get_proper_version()` — 支持 latest 和版本号匹配
- [x] 9.4 实现 `Kotlin::get_download_info()` — 构造编译器 zip 下载 URL
- [x] 9.5 实现 `Kotlin::get_expected_checksum()` — 返回 None（无官方校验）
- [x] 9.6 实现 `Kotlin::get_exe_path()` — 返回 kotlinc/kotlinc.bat 的绝对路径
- [x] 9.7 实现 `Kotlin::get_kotlin_builtin_tool_path_and_version()` — kotlin 内置工具查找
- [x] 9.8 编写 Kotlin 版本解析测试
- [x] 9.9 编写 Kotlin 下载信息测试

## 10. Shim 代理脚本与 setup 命令

- [x] 10.1 在 `cmd/command/setup.mbt` 为 Python 创建 Shim（python）
- [x] 10.2 为 Rust 创建 Shim（rustc、cargo — cargo 归属 rust）
- [x] 10.3 为 Deno 创建 Shim（deno）
- [x] 10.4 为 Java 创建 Shim（java、javac、jar — javac/jar 归属 java）
- [x] 10.5 为 Kotlin 创建 Shim（kotlinc、kotlin — kotlin 归属 kotlin）
- [x] 10.6 更新 Windows Shim 创建逻辑 — 对应的 .ps1 和 .cmd 文件

## 11. 文档更新

- [x] 11.1 更新 `README.md` — 新增 5 种语言的命令示例和使用说明
- [x] 11.2 更新 `README_en.md` — 同步英文版文档
- [x] 11.3 更新 `mvm config` 命令帮助 — 新增镜像配置说明
- [x] 11.4 更新 `mvm install` 命令帮助 — 新增语言示例

## 12. 集成测试与验证

- [x] 12.1 编写 `mvm install python@3.12` 安装流程集成测试（需手动 E2E 验证）
- [x] 12.2 编写 `mvm install rust@stable` 安装流程集成测试（需手动 E2E 验证）
- [x] 12.3 编写 `mvm install deno@latest` 安装流程集成测试（需手动 E2E 验证）
- [x] 12.4 编写 `mvm install java@21` 安装流程集成测试（需手动 E2E 验证）
- [x] 12.5 编写 `mvm install kotlin@latest` 安装流程集成测试（需手动 E2E 验证）
- [x] 12.6 编写 `mvm use/pin/unuse` 跨语言版本切换测试（需手动 E2E 验证）
- [x] 12.7 编写内置工具运行测试（cargo、javac、jar、kotlinc、kotlin）（需手动 E2E 验证）
- [x] 12.8 编写镜像配置替换验证测试（url.mbt 中已覆盖）
- [x] 12.9 编写 `mvm config set china` 一键配置验证测试（config.mbt 中已覆盖）
