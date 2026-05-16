## ADDED Requirements

### Requirement: Java 版本索引获取

Java (JDK) 版本信息从 Adoptium API 获取并缓存。

#### Scenario: 获取 JDK 版本列表
- **WHEN** 需要解析 Java 版本
- **THEN** 从 `https://api.adoptium.net/v3/assets/latest/<version>/hotspot` 获取版本信息
- **THEN** 解析为结构化的版本信息数组（按版本号倒序排序）
- **THEN** 缓存到 `$MVM_HOME/cache/java_index.json`

#### Scenario: 获取所有可用版本
- **WHEN** 不指定具体版本号查询
- **THEN** 从 `https://api.adoptium.net/v3/info/available_releases` 获取可用版本列表

---

### Requirement: Java 版本解析

支持 LTS 标签、latest、主版本号、完整版本号。

#### Scenario: 安装最新 LTS 版本
- **WHEN** 运行 `mvm install java` 或 `mvm install java@lts`
- **THEN** 解析为最新的 LTS 版本（如 `21.0.2`）

#### Scenario: 安装指定 LTS 版本系列
- **WHEN** 运行 `mvm install java@8`、`mvm install java@11`、`mvm install java@17`、`mvm install java@21`
- **THEN** 解析为该 LTS 系列的最新补丁版本

#### Scenario: 安装 latest 版本
- **WHEN** 运行 `mvm install java@latest`
- **THEN** 解析为最新的可用版本（包括非 LTS）

#### Scenario: 安装指定完整版本
- **WHEN** 运行 `mvm install java@21.0.2`
- **THEN** 直接使用 `21.0.2` 作为目标版本

#### Scenario: 安装不存在的版本
- **WHEN** 运行 `mvm install java@5`
- **THEN** 报错 `"找不到版本：5"`

---

### Requirement: Java 下载信息构造

#### Scenario: macOS ARM 下载
- **WHEN** 在 macOS ARM 上安装 JDK 21.0.2
- **THEN** 下载 URL 为 `https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.2%2B13/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.2_13.tar.gz`
- **THEN** `root_path_depth` 为 1

#### Scenario: Linux x64 下载
- **WHEN** 在 Linux x64 上安装 JDK 21.0.2
- **THEN** 下载 URL 包含 `x64_linux` 平台标识

#### Scenario: Windows x64 下载
- **WHEN** 在 Windows x64 上安装 JDK 21.0.2
- **THEN** 下载 URL 为 `.zip` 格式

#### Scenario: 镜像替换
- **WHEN** `java_mirror` 已配置
- **THEN** URL 被替换为镜像地址
- **WHEN** 无 `java_mirror` 但 `github_proxy` 已配置
- **THEN** GitHub URL 被代理替换

---

### Requirement: Java SHA256 校验

从 Adoptium release assets 获取校验值。

#### Scenario: 校验值获取成功
- **WHEN** 从 release assets 中查找 `.sha256.txt` 文件
- **THEN** 解析并返回对应归档文件的 SHA256 值
- **THEN** 返回 `Some("sha256_hash")`

#### Scenario: 校验值获取失败
- **WHEN** 无法获取 SHA256 文件
- **THEN** 返回 `None`

---

### Requirement: Java 可执行文件路径

#### Scenario: macOS/Linux java 路径
- **WHEN** 查询 JDK 21.0.2 的 java 可执行文件路径（Unix 系统）
- **THEN** 返回 `$MVM_HOME/tools/java/21.0.2/bin/java`

#### Scenario: Windows java 路径
- **WHEN** 查询 JDK 21.0.2 的 java 可执行文件路径（Windows 系统）
- **THEN** 返回 `$MVM_HOME/tools/java/21.0.2/bin/java.exe`

---

### Requirement: Java 内置工具

javac 和 jar 是 JDK 的内置工具，与 Java 版本绑定。

#### Scenario: javac/jar 作为内置工具
- **WHEN** `Tool::is_java_builtin_tools(Javac)` 和 `Tool::is_java_builtin_tools(Jar)` 为 true
- **THEN** javac 和 jar 的版本与安装的 JDK 版本一致

#### Scenario: javac 可执行文件路径
- **WHEN** 查询 javac 可执行文件路径（macOS/Linux）
- **THEN** 返回 `$MVM_HOME/tools/java/<version>/bin/javac`
- **WHEN** 查询 javac 可执行文件路径（Windows）
- **THEN** 返回 `$MVM_HOME/tools/java/<version>/bin/javac.exe`

#### Scenario: jar 可执行文件路径
- **WHEN** 查询 jar 可执行文件路径（macOS/Linux）
- **THEN** 返回 `$MVM_HOME/tools/java/<version>/bin/jar`
- **WHEN** 查询 jar 可执行文件路径（Windows）
- **THEN** 返回 `$MVM_HOME/tools/java/<version>/bin/jar.exe`

#### Scenario: Java 内置工具版本获取
- **WHEN** 通过 `Java::get_java_builtin_tool_path_and_version(Javac, java_tool_exe)` 获取
- **THEN** 返回 `ToolExe::new(Javac, javac_path, java_version, dependent_tool_exe=Some(java_tool_exe))`
- **THEN** javac 版本与 JDK 版本相同

#### Scenario: javac/jar Shim 脚本归属
- **WHEN** `mvm setup` 创建 javac 和 jar 的 Shim 脚本
- **THEN** 内容为 `mvm run java -- javac "$@"` 和 `mvm run java -- jar "$@"`（归属 java 工具）

---

### Requirement: Java 版本号格式

Java 版本号不带 "v" 前缀（与 Go 一致）。

#### Scenario: 版本号匹配
- **WHEN** 调用 `match_version(Java, "21", "21.0.2")`
- **THEN** 返回 `true`

#### Scenario: 内部版本号存储
- **WHEN** Java 版本在 `mvm.json` 中写入
- **THEN** 使用不带 "v" 前缀的格式（如 `"21.0.2"`）
