## ADDED Requirements

### Requirement: Deno 版本索引获取

Deno 版本信息从 GitHub releases API 获取并缓存。

#### Scenario: 获取 Deno 版本列表
- **WHEN** 需要解析 Deno 版本
- **THEN** 从 `https://github.com/denoland/deno/releases` 获取版本列表
- **THEN** 解析为结构化的版本信息数组（按版本号倒序排序）
- **THEN** 缓存到 `$MVM_HOME/cache/deno_index.json`

#### Scenario: 版本缓存命中
- **WHEN** 缓存文件存在且未过期
- **THEN** 直接从缓存读取

---

### Requirement: Deno 版本解析

支持 latest 和具体版本号。

#### Scenario: 安装最新版本
- **WHEN** 运行 `mvm install deno` 或 `mvm install deno@latest`
- **THEN** 解析为最新的稳定版本号（如 `2.0.0`）

#### Scenario: 安装指定完整版本
- **WHEN** 运行 `mvm install deno@1.40.0`
- **THEN** 直接使用 `1.40.0` 作为目标版本

#### Scenario: 安装指定主版本
- **WHEN** 运行 `mvm install deno@1`
- **THEN** 解析为 1.x 系列的最新版本

#### Scenario: 安装不存在的版本
- **WHEN** 运行 `mvm install deno@99.99`
- **THEN** 报错 `"找不到版本：99.99"`

---

### Requirement: Deno 下载信息构造

Deno 是单一二进制文件，压缩包内无子目录。

#### Scenario: macOS ARM 下载
- **WHEN** 在 macOS ARM 上安装 Deno 2.0.0
- **THEN** 下载 URL 为 `https://github.com/denoland/deno/releases/download/v2.0.0/deno-aarch64-apple-darwin.zip`
- **THEN** `root_path_depth` 为 0（压缩包内直接是 deno 二进制文件）

#### Scenario: Linux x64 下载
- **WHEN** 在 Linux x64 上安装 Deno 2.0.0
- **THEN** 下载 URL 为 `https://github.com/denoland/deno/releases/download/v2.0.0/deno-x86_64-unknown-linux-gnu.zip`
- **THEN** `root_path_depth` 为 0

#### Scenario: Windows x64 下载
- **WHEN** 在 Windows x64 上安装 Deno 2.0.0
- **THEN** 下载 URL 为 `https://github.com/denoland/deno/releases/download/v2.0.0/deno-x86_64-pc-windows-msvc.zip`
- **THEN** `root_path_depth` 为 0

#### Scenario: GitHub 代理替换
- **WHEN** `github_proxy` 已配置（如 `https://cdn.gh-proxy.org/$URL`）
- **THEN** GitHub 下载 URL 被代理替换

---

### Requirement: Deno SHA256 校验

Deno 无官方 SHA256 校验文件。

#### Scenario: 校验值不可用
- **WHEN** 调用 `Deno::get_expected_checksum(os_info, version)`
- **THEN** 返回 `None`
- **THEN** 安装流程允许 `--skip-verify` 跳过校验

---

### Requirement: Deno 可执行文件路径

Deno 是单一二进制文件，无 bin 子目录。

#### Scenario: macOS/Linux 路径
- **WHEN** 查询 Deno 2.0.0 的可执行文件路径（Unix 系统）
- **THEN** 返回 `$MVM_HOME/tools/deno/2.0.0/deno`

#### Scenario: Windows 路径
- **WHEN** 查询 Deno 2.0.0 的可执行文件路径（Windows 系统）
- **THEN** 返回 `$MVM_HOME/tools/deno/2.0.0/deno.exe`

---

### Requirement: Deno 版本号格式

Deno 版本号使用 "v" 前缀规则。

#### Scenario: 版本号匹配
- **WHEN** 调用 `match_version(Deno, "1.40", "1.40.0")`
- **THEN** 返回 `true`

#### Scenario: 内部版本号存储
- **WHEN** Deno 版本在 `mvm.json` 中写入
- **THEN** 使用带 "v" 前缀的格式（如 `"v2.0.0"`）

---

### Requirement: Deno 安装后处理

Deno 是单一二进制文件，需直接设置可执行权限。

#### Scenario: 权限设置
- **WHEN** 在 Unix 系统安装 Deno 后
- **THEN** 为 `$MVM_HOME/tools/deno/<version>/deno` 设置可执行权限（无 bin 子目录）
