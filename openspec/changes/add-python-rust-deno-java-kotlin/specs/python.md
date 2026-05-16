## ADDED Requirements

### Requirement: Python 版本索引获取

Python 版本信息从远程 API 获取并缓存，支持版本号模糊匹配。

#### Scenario: 获取 Python 版本列表
- **WHEN** 需要解析 Python 版本
- **THEN** 从 `https://endoflife.date/api/python.json` 获取版本列表
- **THEN** 解析为结构化的版本信息数组（按版本号倒序排序）
- **THEN** 缓存到 `$MVM_HOME/cache/python_index.json`

#### Scenario: 版本缓存命中
- **WHEN** 缓存文件 `python_index.json` 存在且未过期
- **THEN** 直接从缓存读取，不发起网络请求

---

### Requirement: Python 版本解析

支持多种版本格式：lts、latest、主版本号、完整版本号。

#### Scenario: 安装最新稳定版
- **WHEN** 运行 `mvm install python` 或 `mvm install python@latest`
- **THEN** 解析为最新的稳定版本号（如 `3.12.4`）

#### Scenario: 安装指定主版本
- **WHEN** 运行 `mvm install python@3.12`
- **THEN** 解析为 3.12.x 系列的最新版本（如 `3.12.4`）

#### Scenario: 安装指定完整版本
- **WHEN** 运行 `mvm install python@3.12.4`
- **THEN** 直接使用 `3.12.4` 作为目标版本

#### Scenario: 安装不存在的版本
- **WHEN** 运行 `mvm install python@2.99`
- **THEN** 报错 `"找不到版本：2.99"`

---

### Requirement: Python 下载信息构造

根据操作系统和架构构造 Python 的下载 URL。

#### Scenario: macOS ARM 下载
- **WHEN** 在 macOS ARM 上安装 Python 3.12.4
- **THEN** 下载 URL 为 `https://www.python.org/ftp/python/3.12.4/Python-3.12.4.tgz`
- **THEN** `root_path_depth` 为 1

#### Scenario: Linux x64 下载
- **WHEN** 在 Linux x64 上安装 Python 3.12.4
- **THEN** 下载 URL 为 `https://www.python.org/ftp/python/3.12.4/Python-3.12.4.tgz`

#### Scenario: Windows x64 下载
- **WHEN** 在 Windows x64 上安装 Python 3.12.4
- **THEN** 下载 URL 为 `https://www.python.org/ftp/python/3.12.4/python-3.12.4-embed-amd64.zip`
- **THEN** `root_path_depth` 为 0

#### Scenario: 镜像替换
- **WHEN** `python_mirror` 配置为 `https://mirrors.aliyun.com/python.org/ftp/python`
- **THEN** URL 被替换为镜像地址

---

### Requirement: Python SHA256 校验

从 python.org 获取 SHA256 校验值。

#### Scenario: 校验值获取成功
- **WHEN** 从 `https://www.python.org/ftp/python/3.12.4/Python-3.12.4.tgz.sha256` 获取校验值
- **THEN** 返回 `Some("sha256_hash_string")`

#### Scenario: 校验值获取失败
- **WHEN** 远程 SHA256 文件不可访问
- **THEN** 返回 `None`，允许 `--skip-verify` 跳过校验继续安装

---

### Requirement: Python 可执行文件路径

根据已安装版本返回 Python 可执行文件的绝对路径。

#### Scenario: macOS/Linux 路径
- **WHEN** 查询 Python 3.12.4 的可执行文件路径（Unix 系统）
- **THEN** 返回 `$MVM_HOME/tools/python/3.12.4/bin/python3`

#### Scenario: Windows 路径
- **WHEN** 查询 Python 3.12.4 的可执行文件路径（Windows 系统）
- **THEN** 返回 `$MVM_HOME/tools/python/3.12.4/python.exe`

---

### Requirement: Python 版本号格式

Python 版本号使用 "v" 前缀规则（与 Node/Bun/Zig 一致）。

#### Scenario: 版本号匹配
- **WHEN** 调用 `match_version(Python, "3.12", "3.12.4")`
- **THEN** 返回 `true`（3.12 是 3.12.4 的前缀匹配）

#### Scenario: 内部版本号存储
- **WHEN** Python 版本在 `mvm.json` 中写入
- **THEN** 使用带 "v" 前缀的格式（如 `"v3.12.4"`）
