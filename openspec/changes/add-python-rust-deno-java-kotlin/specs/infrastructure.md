## ADDED Requirements

### Requirement: Tool 枚举扩展

`Tool` 枚举新增 Python、Rust、Cargo、Deno、Java、Javac、Jar、Kotlin、Kotlinc 变体。

#### Scenario: 新工具枚举变体识别
- **WHEN** 调用 `Tool::from_string("python")`
- **THEN** 返回 `Python`

#### Scenario: 新工具枚举字符串输出
- **WHEN** 调用 `Python.to_str()`
- **THEN** 返回 `"python"`

#### Scenario: 可安装工具列表包含新语言
- **WHEN** 调用 `Tool::installable_tools()`
- **THEN** 返回包含 Python、Rust、Deno、Java、Kotlin 的数组

#### Scenario: 全部工具列表包含内置工具
- **WHEN** 调用 `Tool::all_tools()`
- **THEN** 返回包含 Cargo、Javac、Jar、Kotlinc 的数组

#### Scenario: Rust 内置工具判断
- **WHEN** 调用 `Tool::is_rust_builtin_tools(Cargo)`
- **THEN** 返回 `true`
- **WHEN** 调用 `Tool::is_rust_builtin_tools(Rust)`
- **THEN** 返回 `false`

#### Scenario: Java 内置工具判断
- **WHEN** 调用 `Tool::is_java_builtin_tools(Javac)` 或 `Tool::is_java_builtin_tools(Jar)`
- **THEN** 返回 `true`
- **WHEN** 调用 `Tool::is_java_builtin_tools(Java)`
- **THEN** 返回 `false`

#### Scenario: Kotlin 内置工具判断
- **WHEN** 调用 `Tool::is_kotlin_builtin_tools(Kotlinc)`
- **THEN** 返回 `true`
- **WHEN** 调用 `Tool::is_kotlin_builtin_tools(Kotlin)`
- **THEN** 返回 `false`

#### Scenario: 内置工具归属关系
- **WHEN** 调用 `Tool::get_belonging_tools(Cargo)`
- **THEN** 返回 `Rust`
- **WHEN** 调用 `Tool::get_belonging_tools(Javac)` 或 `Tool::get_belonging_tools(Jar)`
- **THEN** 返回 `Java`
- **WHEN** 调用 `Tool::get_belonging_tools(Kotlinc)`
- **THEN** 返回 `Kotlin`

#### Scenario: 无效工具名报错
- **WHEN** 调用 `Tool::from_string("foobar")`
- **THEN** 抛出错误 `"不支持的工具：foobar"`

---

### Requirement: 通用分发层扩展

`common.mbt` 中的 match 分支需覆盖所有新工具。

#### Scenario: 版本解析分发
- **WHEN** 调用 `get_target_version(os_info, Python, "3.12")`
- **THEN** 分发到 `Python::get_target_version(os_info, "3.12", version_count)`
- **WHEN** 调用 `get_target_version(os_info, Rust, "stable")`
- **THEN** 分发到 `Rust::get_target_version(os_info, "stable", version_count)`

#### Scenario: 下载信息分发
- **WHEN** 调用 `get_download_info(os_info, Deno, "v2.0.0")`
- **THEN** 分发到 `Deno::get_download_info(os_info, "v2.0.0")`

#### Scenario: 校验值获取分发
- **WHEN** 调用 `get_expected_checksum(os_info, Java, "21")`
- **THEN** 分发到 `Java::get_expected_checksum(os_info, "21")`

#### Scenario: 可执行路径分发
- **WHEN** 调用 `get_exe_path_for_version(Kotlin, "2.0.0")`
- **THEN** 分发到 `Kotlin::get_exe_path("2.0.0")`

#### Scenario: 版本号匹配规则
- **WHEN** 调用 `match_version(Python, "3.12", "3.12.4")`
- **THEN** 返回 `true`（Python 使用 "v" 前缀规则）
- **WHEN** 调用 `match_version(Java, "21", "21.0.2")`
- **THEN** 返回 `true`（Java 不带 "v" 前缀规则）

#### Scenario: 内置工具可执行文件查找
- **WHEN** 调用 `get_tool_exe_path(Cargo)`
- **THEN** 先查找 Rust 版本，再通过 `Rust::get_rust_builtin_tool_path_and_version` 获取 Cargo 的 ToolExe
- **WHEN** 调用 `get_tool_exe_path(Javac)`
- **THEN** 先查找 Java 版本，再通过 `Java::get_java_builtin_tool_path_and_version` 获取 Javac 的 ToolExe

---

### Requirement: 全局配置扩展

`GlobalConfig` 结构体新增 5 个镜像字段。

#### Scenario: GlobalConfig 新增字段解析
- **WHEN** 解析 JSON `{ "python_mirror": "https://mirrors.aliyun.com/python.org/ftp/python" }`
- **THEN** `GlobalConfig.python_mirror` 为 `Some("https://mirrors.aliyun.com/python.org/ftp/python")`

#### Scenario: GlobalConfig 字段序列化
- **WHEN** 序列化包含 `rust_mirror` 的 GlobalConfig
- **THEN** JSON 输出包含 `"rust_mirror": "https://..."` 字段

#### Scenario: 镜像配置一键设置
- **WHEN** 运行 `mvm config set china`
- **THEN** 自动设置 python_mirror、rust_mirror、java_mirror 等中国区镜像地址

---

### Requirement: 项目配置扩展

`Config`（mvm.json）结构体新增 5 个语言字段。

#### Scenario: Config 新增字段解析
- **WHEN** 解析 JSON `{ "python": "3.12.4", "rust": "1.80.0" }`
- **THEN** `Config.python` 为 `Some("3.12.4")`，`Config.rust` 为 `Some("1.80.0")`

#### Scenario: Config get_value 支持新工具
- **WHEN** 调用 `config.get_value(Python)`
- **THEN** 返回 `config.python`
- **WHEN** 调用 `config.get_value(Rust)`
- **THEN** 返回 `config.rust`

---

### Requirement: URL 替换扩展

`apply_global_config()` 支持新语言的镜像替换。

#### Scenario: Python 镜像替换
- **WHEN** URL 包含 `PYTHON_RELEASE_URL` 且 `python_mirror` 已配置
- **THEN** 将 URL 中的 `PYTHON_RELEASE_URL` 替换为 `python_mirror` 值

#### Scenario: Rust 镜像替换
- **WHEN** URL 包含 `RUST_RELEASE_URL` 且 `rust_mirror` 已配置
- **THEN** 替换为 `rust_mirror` 值

#### Scenario: Java 镜像替换
- **WHEN** URL 包含 `JAVA_RELEASE_URL` 且 `java_mirror` 已配置
- **THEN** 替换为 `java_mirror` 值

#### Scenario: Deno/Kotlin 使用 github_proxy
- **WHEN** Deno/Kotlin 的下载 URL 以 `https://github.com/` 开头
- **THEN** 使用 `github_proxy` 配置替换（无专属镜像字段）

---

### Requirement: Shim 代理脚本生成

`mvm setup` 为新语言创建 Shim 脚本。

#### Scenario: Unix Shim 创建
- **WHEN** 运行 `mvm setup`（Unix 环境）
- **THEN** 在 `$MVM_HOME/bin/` 下创建 `python`、`rustc`、`cargo`、`deno`、`java`、`javac`、`jar`、`kotlinc`、`kotlin` 代理脚本

#### Scenario: Windows Shim 创建
- **WHEN** 运行 `mvm setup`（Windows 环境）
- **THEN** 在 `$MVM_HOME/bin/` 下创建对应的 `.ps1` 和 `.cmd` 文件

#### Scenario: Shim 脚本内容
- **WHEN** 查看 `python` Shim 脚本内容
- **THEN** 内容为 `#!/bin/sh\nmvm run python -- python "$@"`
- **WHEN** 查看 `cargo` Shim 脚本内容
- **THEN** 内容为 `#!/bin/sh\nmvm run rust -- cargo "$@"`（cargo 归属 rust）

---

### Requirement: 安装后权限设置

`post_install()` 为新语言设置可执行权限。

#### Scenario: Python 可执行权限
- **WHEN** 在 Unix 系统安装 Python 后
- **THEN** 为 `bin/python3` 设置可执行权限

#### Scenario: Rust 可执行权限
- **WHEN** 在 Unix 系统安装 Rust 后
- **THEN** 为 `bin/rustc`、`bin/cargo` 设置可执行权限

#### Scenario: Java 可执行权限
- **WHEN** 在 Unix 系统安装 Java 后
- **THEN** 为 `bin/java`、`bin/javac`、`bin/jar` 设置可执行权限

#### Scenario: Kotlin 可执行权限
- **WHEN** 在 Unix 系统安装 Kotlin 后
- **THEN** 为 `bin/kotlinc`、`bin/kotlin` 设置可执行权限

#### Scenario: Deno 可执行权限
- **WHEN** 在 Unix 系统安装 Deno 后
- **THEN** 为 `deno` 设置可执行权限（无 bin 子目录）
