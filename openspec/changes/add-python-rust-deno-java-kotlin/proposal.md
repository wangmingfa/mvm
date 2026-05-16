## Why

mvm 目前仅支持 Node.js、Bun、Zig、Go 四种语言，而现代开发者的工具链远不止这些。Python 是数据科学与 AI 开发的基石，Rust 是高性能系统编程的潮流，Deno 是 Node.js 的现代替代方案，Java 是企业级开发的基石，Kotlin 则是 JVM 生态的未来和 Android 开发的首选。

用户需要为每种语言单独安装和维护版本管理器（pyenv、rustup 等），增加了工具链复杂度和学习成本。mvm 的核心理念是"一个工具管理所有语言版本"，将这些高频语言纳入支持范围，可以：

1. **减少工具链碎片化**：一个 `mvm install python@3.12` 替代 `pyenv install 3.12`
2. **保持一致的版本切换体验**：`mvm pin` / `mvm use` 跨语言行为一致
3. **扩大用户群体**：覆盖数据科学、系统编程、前端、企业开发等更多场景
4. **强化 mvm 定位**：真正成为"One Tool to Manage Them All"

## What

为 mvm 新增五种语言/运行时的版本管理支持：

### Python
- 支持安装、切换、锁定 Python 版本（3.x 系列）
- 版本来源：python.org 官方发布
- 支持 LTS（稳定版）和 latest 标签
- 可执行文件：`python` / `python3`

### Rust
- 支持安装、切换、锁定 Rust 版本（stable / nightly / beta 通道）
- 版本来源：rust-lang.org 官方发布
- 支持通道标签：`stable`、`nightly`、`beta`
- 可执行文件：`rustc`、`cargo`、`rustup`（Rust 内置工具，类似 Node 的 npm）

### Deno
- 支持安装、切换、锁定 Deno 版本
- 版本来源：github.com/denoland/deno releases
- 可执行文件：`deno`

### Java (JDK)
- 支持安装、切换、锁定 JDK 版本（8、11、17、21 等 LTS 版本）
- 版本来源： Adoptium (Eclipse Temurin) — 最主流的开源 JDK 发行版
- 支持 LTS 标签：`jdk@8`、`jdk@11`、`jdk@17`、`jdk@21`
- 可执行文件：`java`、`javac`、`jar`

### Kotlin
- 支持安装、切换、锁定 Kotlin 编译器版本
- 版本来源：github.com/JetBrains/kotlin releases
- 可执行文件：`kotlinc`、`kotlin`

每种语言都需要实现：
- `Tool` 枚举扩展
- 版本索引获取与解析（`get_target_version`）
- 下载信息构造（`get_download_info`）
- SHA256 校验获取（`get_expected_checksum`）
- 可执行文件路径解析（`get_exe_path`）
- Shim 代理脚本生成
- `mvm.json` 配置读写支持
- `mvm config set <tool>_mirror` 镜像配置支持

## Impact

### 核心代码改动
- **`cmd/tools/tool_def/tool.mbt`**：`Tool` 枚举新增 Python、Rust、Deno、Java、Kotlin 五个变体，更新 `from_string`、`to_str`、`installable_tools`、`all_tools` 等方法
- **`cmd/tools/tool_def/` 下新增五个文件**：`python.mbt`、`rust.mbt`、`deno.mbt`、`java.mbt`、`kotlin.mbt`，各自实现版本解析、下载、校验、路径逻辑
- **`cmd/tools/tool_def/url.mbt`**：新增各语言的 URL 替换规则（镜像支持）
- **`cmd/tools/tool_def/config.mbt`**：新增各语言的镜像配置字段
- **`cmd/command/install.mbt`** / **`run.mbt`** 等：适配新工具的安装和运行逻辑

### 配置体系改动
- **`mvm.json`**：新增 `python`、`rust`、`deno`、`java`、`kotlin` 字段
- **`config.json`**：新增 `python_mirror`、`rust_mirror`、`deno_mirror`、`java_mirror`、`kotlin_mirror` 配置项
- **Shim 脚本**：`mvm setup` 需为每种新语言生成对应的代理脚本（`python`、`rustc`、`cargo`、`deno`、`java`、`javac`、`kotlinc`、`kotlin`）

### 文档改动
- **`README.md`** 和 **`README_en.md`**：新增五种语言的命令示例和使用说明
- **`mvm config set china`**：扩展中国区镜像配置，涵盖新语言

### 依赖风险
- Rust 的 `cargo` 是内置工具，类似 Node 的 `npm`，需特殊处理（Rust 内置工具模式）
- Java 的 JDK 包含多个可执行文件（`java`、`javac`、`jar`），类似 Node 的内置工具模式
- 各语言的发布格式差异较大（tar.gz、zip、独立二进制等），需逐一适配解压逻辑
- 部分语言的版本索引 API 响应格式各不相同，需分别实现解析逻辑
