## ADDED Requirements

### Requirement: Rust 版本索引获取

Rust 版本信息从 rust-lang.org 的 channel manifest（TOML 格式）获取。

#### Scenario: 获取 stable 通道版本
- **WHEN** 需要解析 Rust stable 版本
- **THEN** 从 `https://static.rust-lang.org/dist/channel-rust-stable.toml` 获取 manifest
- **THEN** 解析 manifest 提取版本号和各平台的可用性信息
- **THEN** 缓存到 `$MVM_HOME/cache/rust_stable_manifest.toml`

#### Scenario: 获取 nightly 通道版本
- **WHEN** 需要解析 Rust nightly 版本
- **THEN** 从 `https://static.rust-lang.org/dist/channel-rust-nightly.toml` 获取 manifest

#### Scenario: 获取 beta 通道版本
- **WHEN** 需要解析 Rust beta 版本
- **THEN** 从 `https://static.rust-lang.org/dist/channel-rust-beta.toml` 获取 manifest

---

### Requirement: Rust 版本解析

支持 stable/nightly/beta 通道标签和具体版本号。

#### Scenario: 安装 stable 版本
- **WHEN** 运行 `mvm install rust` 或 `mvm install rust@stable`
- **THEN** 解析为当前 stable 通道的最新版本（如 `1.80.0`）

#### Scenario: 安装 nightly 版本
- **WHEN** 运行 `mvm install rust@nightly`
- **THEN** 解析为当前 nightly 通道的最新版本（如 `1.81.0-nightly`）

#### Scenario: 安装 beta 版本
- **WHEN** 运行 `mvm install rust@beta`
- **THEN** 解析为当前 beta 通道的最新版本

#### Scenario: 安装指定版本
- **WHEN** 运行 `mvm install rust@1.80.0`
- **THEN** 直接使用 `1.80.0` 作为目标版本

#### Scenario: 安装指定主版本
- **WHEN** 运行 `mvm install rust@1.80`
- **THEN** 解析为 1.80.x 系列的最新版本

#### Scenario: 平台兼容性校验
- **WHEN** 解析版本后
- **THEN** 检查 manifest 中是否包含当前操作系统+架构的目标三元组（如 `aarch64-apple-darwin`）
- **THEN** 不兼容时报错 `"版本 {version} 不支持 {os} 操作系统下的 {arch} 架构"`

---

### Requirement: Rust 下载信息构造

#### Scenario: macOS ARM 下载
- **WHEN** 在 macOS ARM 上安装 Rust 1.80.0
- **THEN** 下载 URL 为 `https://static.rust-lang.org/dist/rust-1.80.0-aarch64-apple-darwin.tar.gz`
- **THEN** `root_path_depth` 为 1

#### Scenario: Linux x64 下载
- **WHEN** 在 Linux x64 上安装 Rust 1.80.0
- **THEN** 下载 URL 为 `https://static.rust-lang.org/dist/rust-1.80.0-x86_64-unknown-linux-gnu.tar.gz`

#### Scenario: Windows x64 下载
- **WHEN** 在 Windows x64 上安装 Rust 1.80.0
- **THEN** 下载 URL 为 `https://static.rust-lang.org/dist/rust-1.80.0-x86_64-pc-windows-msvc.zip`

#### Scenario: 镜像替换
- **WHEN** `rust_mirror` 配置为 `https://mirrors.aliyun.com/rust-lang/dist`
- **THEN** URL 被替换为镜像地址

---

### Requirement: Rust SHA256 校验

从 manifest 文件中提取校验值。

#### Scenario: 校验值获取成功
- **WHEN** 从 channel manifest 中查找对应平台的 sha256 字段
- **THEN** 返回 `Some("sha256_hash")`

#### Scenario: 校验值获取失败
- **WHEN** manifest 中缺少对应平台的校验信息
- **THEN** 返回 `None`

---

### Requirement: Rust 可执行文件路径

#### Scenario: macOS/Linux rustc 路径
- **WHEN** 查询 Rust 1.80.0 的 rustc 可执行文件路径（Unix 系统）
- **THEN** 返回 `$MVM_HOME/tools/rust/1.80.0/bin/rustc`

#### Scenario: Windows rustc 路径
- **WHEN** 查询 Rust 1.80.0 的 rustc 可执行文件路径（Windows 系统）
- **THEN** 返回 `$MVM_HOME/tools/rust/1.80.0/bin/rustc.exe`

---

### Requirement: Cargo 内置工具

Cargo 是 Rust 的内置工具，与 Rust 版本绑定。

#### Scenario: Cargo 作为内置工具
- **WHEN** `Tool::is_rust_builtin_tools(Cargo)` 为 true
- **THEN** Cargo 的版本与安装的 Rust 版本一致

#### Scenario: Cargo 可执行文件路径
- **WHEN** 查询 Cargo 可执行文件路径（macOS/Linux）
- **THEN** 返回 `$MVM_HOME/tools/rust/<version>/bin/cargo`
- **WHEN** 查询 Cargo 可执行文件路径（Windows）
- **THEN** 返回 `$MVM_HOME/tools/rust/<version>/bin/cargo.exe`

#### Scenario: Cargo 版本获取
- **WHEN** 通过 `Rust::get_rust_builtin_tool_path_and_version(Cargo, rust_tool_exe)` 获取
- **THEN** 返回 `ToolExe::new(Cargo, cargo_path, rust_version, dependent_tool_exe=Some(rust_tool_exe))`

#### Scenario: Cargo Shim 脚本归属
- **WHEN** `mvm setup` 创建 Cargo Shim 脚本
- **THEN** 脚本内容为 `mvm run rust -- cargo "$@"`（归属 rust 工具）

---

### Requirement: Rust 版本号格式

Rust 版本号使用 "v" 前缀规则（与 Node/Bun/Zig 一致）。

#### Scenario: 版本号匹配
- **WHEN** 调用 `match_version(Rust, "1.80", "1.80.0")`
- **THEN** 返回 `true`

#### Scenario: nightly 版本号存储
- **WHEN** nightly 版本写入 `mvm.json`
- **THEN** 格式为 `"v1.81.0-nightly-2024-08-01"` 或简化格式 `"nightly-2024-08-01"`
