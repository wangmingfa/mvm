## ADDED Requirements

### Requirement: Kotlin 版本索引获取

Kotlin 编译器版本信息从 GitHub releases API 获取并缓存。

#### Scenario: 获取 Kotlin 版本列表
- **WHEN** 需要解析 Kotlin 版本
- **THEN** 从 `https://github.com/JetBrains/kotlin/releases` 获取版本列表
- **THEN** 解析为结构化的版本信息数组（按版本号倒序排序）
- **THEN** 缓存到 `$MVM_HOME/cache/kotlin_index.json`

#### Scenario: 版本缓存命中
- **WHEN** 缓存文件存在且未过期
- **THEN** 直接从缓存读取

---

### Requirement: Kotlin 版本解析

支持 latest 和具体版本号。

#### Scenario: 安装最新版本
- **WHEN** 运行 `mvm install kotlin` 或 `mvm install kotlin@latest`
- **THEN** 解析为最新的稳定版本号（如 `2.0.0`）

#### Scenario: 安装指定完整版本
- **WHEN** 运行 `mvm install kotlin@1.9.24`
- **THEN** 直接使用 `1.9.24` 作为目标版本

#### Scenario: 安装指定主版本
- **WHEN** 运行 `mvm install kotlin@1.9`
- **THEN** 解析为 1.9.x 系列的最新版本

#### Scenario: 安装不存在的版本
- **WHEN** 运行 `mvm install kotlin@99.99`
- **THEN** 报错 `"找不到版本：99.99"`

---

### Requirement: Kotlin 下载信息构造

#### Scenario: macOS/Linux/Windows 下载
- **WHEN** 安装 Kotlin 2.0.0
- **THEN** 下载 URL 为 `https://github.com/JetBrains/kotlin/releases/download/v2.0.0/kotlin-compiler-2.0.0.zip`
- **THEN** `root_path_depth` 为 1

#### Scenario: GitHub 代理替换
- **WHEN** `github_proxy` 已配置
- **THEN** GitHub 下载 URL 被代理替换

---

### Requirement: Kotlin SHA256 校验

Kotlin 无官方 SHA256 校验文件。

#### Scenario: 校验值不可用
- **WHEN** 调用 `Kotlin::get_expected_checksum(os_info, version)`
- **THEN** 返回 `None`
- **THEN** 安装流程允许 `--skip-verify` 跳过校验

---

### Requirement: Kotlin 可执行文件路径

#### Scenario: macOS/Linux kotlinc 路径
- **WHEN** 查询 Kotlin 2.0.0 的 kotlinc 可执行文件路径（Unix 系统）
- **THEN** 返回 `$MVM_HOME/tools/kotlin/2.0.0/bin/kotlinc`

#### Scenario: Windows kotlinc 路径
- **WHEN** 查询 Kotlin 2.0.0 的 kotlinc 可执行文件路径（Windows 系统）
- **THEN** 返回 `$MVM_HOME/tools/kotlin/2.0.0/bin/kotlinc.bat`

---

### Requirement: Kotlin 内置工具

`kotlin` 命令是 `kotlinc` 编译器包的附属可执行文件。

#### Scenario: kotlin 作为内置工具
- **WHEN** `Tool::is_kotlin_builtin_tools(Kotlinc)` 为 true
- **THEN** kotlin（运行工具）和 kotlinc（编译器）版本一致

#### Scenario: kotlin 可执行文件路径
- **WHEN** 查询 kotlin 可执行文件路径（macOS/Linux）
- **THEN** 返回 `$MVM_HOME/tools/kotlin/<version>/bin/kotlin`
- **WHEN** 查询 kotlin 可执行文件路径（Windows）
- **THEN** 返回 `$MVM_HOME/tools/kotlin/<version>/bin/kotlin.bat`

#### Scenario: Kotlin 内置工具版本获取
- **WHEN** 通过 `Kotlin::get_kotlin_builtin_tool_path_and_version(Kotlinc, kotlin_tool_exe)` 获取
- **THEN** 返回 `ToolExe::new(Kotlinc, kotlinc_path, kotlin_version, dependent_tool_exe=Some(kotlin_tool_exe))`

#### Scenario: Kotlinc Shim 脚本归属
- **WHEN** `mvm setup` 创建 kotlinc 和 kotlin 的 Shim 脚本
- **THEN** 内容分别为 `mvm run kotlin -- kotlinc "$@"` 和 `mvm run kotlin -- kotlin "$@"`（归属 kotlin 工具）

---

### Requirement: Kotlin 版本号格式

Kotlin 版本号不带 "v" 前缀（与 Go/Java 一致）。

#### Scenario: 版本号匹配
- **WHEN** 调用 `match_version(Kotlin, "1.9", "1.9.24")`
- **THEN** 返回 `true`

#### Scenario: 内部版本号存储
- **WHEN** Kotlin 版本在 `mvm.json` 中写入
- **THEN** 使用不带 "v" 前缀的格式（如 `"2.0.0"`）

---

### Requirement: Kotlin 安装后处理

#### Scenario: 权限设置
- **WHEN** 在 Unix 系统安装 Kotlin 后
- **THEN** 为 `bin/kotlinc`、`bin/kotlin` 设置可执行权限
