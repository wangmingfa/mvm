## Context

mvm 当前支持 4 种语言（Node.js、Bun、Zig、Go），每种语言通过以下统一架构实现：

1. **`Tool` 枚举**（`tool_def/tool.mbt`）定义所有工具变体
2. **语言专属实现文件**（`tool_def/<lang>.mbt`）各实现 4 个核心方法：
   - `get_target_version(os, version, version_count)` — 版本索引解析
   - `get_download_info(os_info, version)` — 下载 URL + headers + 解压深度
   - `get_expected_checksum(os_info, version)` — SHA256 校验值获取
   - `get_exe_path(version)` — 可执行文件路径
3. **通用分发层**（`tools/common.mbt`）通过 match 分发到各语言实现
4. **URL/配置层**（`tool_def/url.mbt`、`config.mbt`）处理镜像替换和全局/项目配置
5. **Shim 代理**（`tools/common.mbt`）为每个工具创建 wrapper 脚本
6. **内置工具模式** — Node 的 npm/npx/corepack 依赖 Node 本体，通过 `ToolExe::dependent_tool_exe` 关联

新增 5 种语言需严格遵循此架构，每个语言一个独立文件，通过 match 分发接入。

## Goals / Non-Goals

**Goals:**
- 为 Python、Rust、Deno、Java、Kotlin 各实现完整的版本管理生命周期（install/use/pin/uninstall/run/which/list/current）
- 保持与现有 4 种语言完全一致的 CLI 体验和版本切换机制
- 支持中国区镜像配置（`mvm config set china` 一键配置）
- Rust 的 `cargo` 和 Java 的 `javac`/`jar` 作为内置工具（类似 Node 的 npm/npx）
- 每种语言独立文件，便于后续维护和扩展

**Non-Goals:**
- 不实现 Python 的 pip 包管理（只管版本）
- 不实现 Rust 的 rustup component 管理（只管 stable/nightly/beta 通道版本）
- 不实现 Java 的 Maven/Gradle 管理（只管 JDK 版本）
- 不实现 Kotlin 的 Kotlin Native 管理（只管 JVM 编译器版本）
- 不支持 Windows ARM 架构（仅 macOS ARM + Windows/Linux x86，与现有策略一致）
- 不重构现有 Tool 枚举为注册式架构（保持简单的枚举扩展模式）

## Architecture

### 1. Tool 枚举扩展

在 `tool_def/tool.mbt` 的 `Tool` 枚举新增：

```
Python
Rust
Cargo        // Rust 内置工具，类似 Npm
Deno
Java         // JDK
Javac        // Java 内置工具
Jar          // Java 内置工具
Kotlin       // Kotlin 编译器
Kotlinc      // Kotlin 内置工具
```

更新配套方法：
- `to_str()` — 新增各变体的字符串映射
- `from_string()` — 新增反向映射（`"python"` → Python 等）
- `installable_tools()` — 新增 Python、Rust、Deno、Java、Kotlin
- `all_tools()` — 新增所有变体（含内置工具）
- 新增 `Tool::is_rust_builtin_tools()` — Cargo 为 Rust 内置工具
- 新增 `Tool::is_java_builtin_tools()` — Javac、Jar 为 Java 内置工具
- 新增 `Tool::is_kotlin_builtin_tools()` — Kotlinc 为 Kotlin 内置工具
- 扩展 `Tool::get_belonging_tools()` — 支持新的内置工具关系

### 2. 语言实现文件

每个语言在 `tool_def/` 下创建独立文件：

| 文件 | 结构体 | 特殊处理 |
|------|--------|----------|
| `python.mbt` | `Python` | 版本号不带 "v" 前缀（类似 Go） |
| `rust.mbt` | `Rust` | 通道标签（stable/nightly/beta）；Cargo 为内置工具 |
| `deno.mbt` | `Deno` | 单一可执行文件；GitHub releases |
| `java.mbt` | `Java` | JDK 包含多可执行文件；Adoptium 发布源 |
| `kotlin.mbt` | `Kotlin` | Kotlinc 为内置工具；GitHub releases |

### 3. 各语言版本源与下载详情

#### Python
- **版本索引**: `https://www.python.org/downloads/` — 解析 HTML 或使用 JSON API（需调研）
- **备选索引**: `https://raw.githubusercontent.com/python/cpython/main/Misc/NEWS.d/` 或第三方 API
- **下载 URL**: `https://www.python.org/ftp/python/<version>/Python-<version>-<os>-<arch>.tgz`
- **实际格式**: macOS 为 `.pkg` 嵌入 tar.gz；Linux 为 `Python-<version>.tgz`；Windows 为 embeddable zip
- **校验源**: `https://www.python.org/ftp/python/<version>/Python-<version>.tgz.asc` 或 SHA256 文件
- **可执行文件**: `python3`（macOS/Linux）、`python.exe`（Windows）
- **路径结构**: `$MVM_HOME/tools/python/<version>/bin/python3`
- **镜像**: `python_mirror` 配置字段，默认值 `https://mirrors.aliyun.com/python.org/ftp/python`（中国区）

#### Rust
- **版本索引**: `https://static.rust-lang.org/dist/channel-rust-stable.toml` — TOML 格式
- **备选索引**: `https://github.com/rust-lang/rust/releases` — JSON API
- **通道标签**: `stable`、`nightly`、`beta`（特殊版本解析逻辑）
- **下载 URL**: `https://static.rust-lang.org/dist/rust-<version>-<os>-<arch>.tar.gz`
- **校验源**: 同目录下的 `.sha256` 文件或 manifest 中的 sha256 字段
- **可执行文件**: `rustc`、`cargo`（cargo 为内置工具，类似 npm）
- **路径结构**: `$MVM_HOME/tools/rust/<version>/bin/rustc`
- **镜像**: `rust_mirror` 配置字段

#### Deno
- **版本索引**: `https://github.com/denoland/deno/releases` — JSON API
- **下载 URL**: `https://github.com/denoland/deno/releases/download/v<version>/deno-<os>-<arch>.zip`
- **校验源**: 无官方 SHA256；可从 release assets 查找或跳过校验
- **可执行文件**: 单一 `deno` 二进制（解压后无子目录）
- **路径结构**: `$MVM_HOME/tools/deno/<version>/deno`
- **root_path_depth**: 0（压缩包内无包装目录）
- **镜像**: 通过 `github_proxy` 配置

#### Java (JDK)
- **版本索引**: `https://api.adoptium.net/v3/assets/latest/<version>/hotspot` — Adoptium API
- **备选索引**: `https://github.com/adoptium/temurin/releases`
- **下载 URL**: `https://github.com/adoptium/temurin<n>/binaries/releases/download/jdk-<version>/OpenJDK<version>-<os>-<arch>.tar.gz`
- **校验源**: release assets 中的 `.sha256.txt` 文件
- **可执行文件**: `java`、`javac`、`jar`（javac/jar 为内置工具）
- **路径结构**: `$MVM_HOME/tools/java/<version>/bin/java`
- **LTS 版本**: 8、11、17、21 为 LTS 标签
- **镜像**: `java_mirror` 配置字段，中国区可用阿里云 Adoptium 镜像

#### Kotlin
- **版本索引**: `https://github.com/JetBrains/kotlin/releases` — JSON API
- **下载 URL**: `https://github.com/JetBrains/kotlin/releases/download/v<version>/kotlin-compiler-<version>.zip`
- **校验源**: 无官方 SHA256；可跳过或从 release metadata 获取
- **可执行文件**: `kotlinc`、`kotlin`（kotlinc 为内置工具）
- **路径结构**: `$MVM_HOME/tools/kotlin/<version>/bin/kotlinc`
- **镜像**: 通过 `github_proxy` 配置

### 4. 通用分发层变更

`tools/common.mbt` 各 match 分支新增：

- `get_target_version()` — 新增 Python/Rust/Deno/Java/Kotlin 分支
- `get_expected_checksum()` — 新增各语言的校验逻辑
- `get_download_info()` — 新增各语言的下载信息分发
- `get_exe_path_for_version()` — 新增各语言的路径分发
- `match_version()` — Rust/Python/Deno 使用 "v" 前缀规则（类似 Node）；Java/Kotlin 不带 "v"（类似 Go）
- `post_install()` — 新增各语言的可执行文件权限设置
- `get_tool_exe_path()` — 支持 Rust/Java/Kotlin 的内置工具查找逻辑

### 5. 配置体系变更

**`GlobalConfig`**（`config.mbt`）新增字段：
```
python_mirror : String?
rust_mirror : String?
deno_mirror : String?
java_mirror : String?
kotlin_mirror : String?
```

**`Config`**（项目配置 `mvm.json`）新增字段：
```
python : String?
rust : String?
deno : String?
java : String?
kotlin : String?
```

**`url.mbt`** `apply_global_config()` 新增镜像匹配分支：
- `python_mirror` — 替换 `PYTHON_RELEASE_URL`
- `rust_mirror` — 替换 `RUST_RELEASE_URL`
- `java_mirror` — 替换 `JAVA_RELEASE_URL`
- Deno 和 Kotlin 使用 `github_proxy`（无专属镜像）

**`mvm config set china`** 扩展 — 一键配置所有语言的国内镜像

### 6. Shim 代理脚本

`mvm setup` 命令需为新增语言创建 Shim 脚本：

| 工具 | Unix Shim | Windows Shim |
|------|-----------|--------------|
| Python | `python` → `mvm run python -- python "$@"` | `python.ps1/cmd` |
| Rust | `rustc` → `mvm run rust -- rustc "$@"` | `rustc.ps1/cmd` |
| Cargo | `cargo` → `mvm run rust -- cargo "$@"` | `cargo.ps1/cmd` |
| Deno | `deno` → `mvm run deno -- deno "$@"` | `deno.ps1/cmd` |
| Java | `java` → `mvm run java -- java "$@"` | `java.ps1/cmd` |
| Javac | `javac` → `mvm run java -- javac "$@"` | `javac.ps1/cmd` |
| Jar | `jar` → `mvm run java -- jar "$@"` | `jar.ps1/cmd` |
| Kotlin | `kotlinc` → `mvm run kotlin -- kotlinc "$@"` | `kotlinc.ps1/cmd` |
| Kotlin | `kotlin` → `mvm run kotlin -- kotlin "$@"` | `kotlin.ps1/cmd` |

### 7. Rust 内置工具模式

Cargo 作为 Rust 的内置工具，与 Node 的 npm 类似：

```
ToolExe::new(
  Cargo,
  cargo_exe_path,
  cargo_version,
  dependent_tool_exe=Some(rust_tool_exe),
)
```

需新增 `Rust::get_rust_builtin_tool_path_and_version()` 方法，类似 `Node::get_node_builtin_tool_path_and_version()`。

### 8. Java 内置工具模式

javac 和 jar 作为 Java (JDK) 的内置工具：

```
ToolExe::new(
  Javac,
  javac_exe_path,
  java_version,  // javac/jar 版本与 JDK 版本一致
  dependent_tool_exe=Some(java_tool_exe),
)
```

需新增 `Java::get_java_builtin_tool_path_and_version()` 方法。

### 9. Kotlin 内置工具模式

`kotlin` 命令作为 `kotlinc` 的附属工具：

```
ToolExe::new(
  Kotlinc,
  kotlinc_exe_path,
  kotlin_version,
  dependent_tool_exe=Some(kotlin_tool_exe),  // 这里 kotlin 指编译器主工具
)
```

## Decisions

### D1: Python 版本索引采用 JSON API 而非 HTML 解析
**理由**: python.org 的下载页面是动态渲染的 HTML，解析不稳定。使用第三方 API（如 `https://endoflife.date/api/python.json`）或构建自定义索引更可靠。

### D2: Rust 使用 TOML manifest 而非 GitHub releases
**理由**: rust-lang.org 的 `channel-rust-stable.toml` 提供了结构化的版本、平台、校验信息，是 rustup 官方使用的数据源，最权威。

### D3: Java 使用 Adoptium API 作为版本源
**理由**: Adoptium (Eclipse Temurin) 是最主流的开源 JDK 发行版，有完善的 API 和丰富的 LTS 版本，社区认可度高。

### D4: Deno 和 Kotlin 校验策略 — 可选跳过
**理由**: Deno 和 Kotlin 的 GitHub releases 不提供官方 SHA256 文件。采用与 Bun 类似的策略：`get_expected_checksum` 返回 None，允许用户通过 `--skip-verify` 跳过校验。

### D5: 版本号前缀规则
**理由**: 
- Python、Rust、Deno 使用 "v" 前缀（类似 Node/Bun/Zig）
- Java、Kotlin 不带 "v" 前缀（类似 Go）
- Rust 的通道标签（stable/nightly/beta）作为特殊版本号处理

### D6: 内置工具统一遵循 Node npm 模式
**理由**: Cargo、javac/jar、kotlin 都与主工具绑定，版本跟随主工具。这与 Node 的 npm/npx/corepack 模式完全一致，复用 `ToolExe::dependent_tool_exe` 机制。

## Risks / Trade-offs

### R1: Python 版本索引稳定性
Python.org 无官方 JSON 版本 API，需依赖第三方或自建索引。第三方 API 可能变更或停服。**缓解**: 使用 `endoflife.date` API（有社区维护），同时支持 `python_mirror` 配置备用源。

### R2: Rust TOML 解析复杂度
Rust 的 channel manifest 是 TOML 格式，MoonBit 标准库可能缺少 TOML 解析器。**缓解**: 使用简化的 TOML 解析（只提取版本和平台信息），或将 TOML 转为更简单的格式处理。

### R3: Java JDK 安装包体积较大
JDK 的 tar.gz 通常 150-300MB，下载时间较长。**缓解**: 利用已有的进度条和缓存机制，支持 `--skip-verify` 快速安装。

### R4: 枚举膨胀
Tool 枚举从 7 个变体增长到 12+ 个，match 分支变长。**缓解**: 当前规模（12 个变体）仍可管理；若未来持续增长（>20 种语言），可考虑重构为注册式架构。

### R5: 平台兼容性
Python 的 macOS 安装包是 `.pkg` 格式，与现有 tar.gz/zip 解压逻辑不同。**缓解**: 为 Python 单独实现解压逻辑，使用 `pkgutil` 或直接下载 tar.gz 源码编译包。
