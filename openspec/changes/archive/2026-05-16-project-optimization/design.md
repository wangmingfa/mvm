## Context

mvm 是一个 MoonBit 编写的多语言版本管理工具，支持 Node.js、Bun、Zig、Go 的安装、切换和管理。当前代码库包含约 20 个包，核心逻辑集中在 `cmd/tools/tool_def`、`cmd/command` 和 `request` 模块中。

当前存在的问题：
- `tool_def/tool.mbt`（876 行）混合了配置读写、URL 替换、工具枚举、缓存管理等职责
- `request/download.mbt` 中 `get_file_size_with_curl` 和 `get_file_size_with_curl_exe` 逻辑几乎相同，仅命令名不同
- 各命令文件中错误处理模式不一：有的用 `raise fail()`，有的用 `@log.error() + return`
- `config set` 命令接受任意字符串作为 URL，无格式校验
- Linux 使用系统 curl/wget，macOS/Windows 使用 MoonBit HTTP 客户端，导致行为差异
- 网络下载失败后无重试机制（仅 SHA256 校验失败有重试）

## Goals / Non-Goals

**Goals：**
- 重构 `tool.mbt`，按职责拆分为 `config.mbt`（配置管理）、`url.mbt`（URL 替换）、`cache.mbt`（缓存逻辑），主文件仅保留 Tool 枚举和基础路径函数
- 合并 `download.mbt` 中重复的 curl 文件大小获取逻辑，提取为通用函数 `get_file_size_by_command(cmd_name, url)`
- 建立统一错误处理约定：命令层面使用 `raise fail()` 向上抛出（由 `run.mbt` 统一捕获），`@log.error() + return` 仅用于"信息提示但不中断"的场景（如版本已安装）
- 为 `config set` 增加 URL 格式校验：检查是否以 `http://` 或 `https://` 开头，`$URL`/`$TOOL` 等模板变量位置是否合理
- 为 `download` 函数增加网络重试机制：失败后自动重试最多 3 次，每次间隔递增
- 补全 `moon.mod.json` 中的 description 和 keywords 字段
- 补充关键路径的测试覆盖

**Non-Goals：**
- 不改变下载策略的跨平台实现方式（保持 Linux 用原生命令、macOS/Windows 用 HTTP 客户端）
- 不新增语言/工具支持
- 不重构命令行解析逻辑
- 不修改 Shim 代理脚本机制

## Architecture

### 文件拆分方案

`tool_def/tool.mbt` → 拆分为：
- `tool_def/tool.mbt`（~150 行）：Tool 枚举、基础路径函数（mvm_home、tool_dir、version_dir）、ToolExe 结构
- `tool_def/config.mbt`（~200 行）：Config/GlobalConfig 结构、配置读写（write_config、get_config、save_global_config 等）
- `tool_def/url.mbt`（~100 行）：UrlReplaceContext、replace_url、apply_global_config
- `tool_def/cache.mbt`（~80 行）：缓存相关（read_cache_file_content、write_cache_file_content、cache_dir、temp_dir、no_cache_flag）

各拆分文件通过 `moon.pkg` 的 `using` 保持包内引用关系不变。对外包（`cmd/tools/common.mbt`）的 `pub using` 需同步更新。

### 代码去重方案

合并 `get_file_size_with_curl` 和 `get_file_size_with_curl_exe`：

```moonbit
async fn get_file_size_by_command(cmd_name : String, url : String) -> Int64? {
  let (code, output) = @process.collect_stdout(cmd_name, ["-sI", url]) catch {
    _ => return None
  }
  if code == 0 {
    // ... 解析 Content-Length
  }
  None
}
```

`get_file_size_with_curl_exe` 改为调用 `get_file_size_by_command("curl.exe", url)`，失败时 fallback 到 PowerShell 方式。

### 错误处理统一约定

| 场景 | 处理方式 | 理由 |
|------|---------|------|
| 命令参数错误 | `raise fail()` | 必须中断，告知用户正确用法 |
| 版本未找到/不支持 | `raise fail()` | 必须中断，无法继续执行 |
| 版本已安装 | `@log.warn() + return` | 提示信息，非错误 |
| 文件不存在但可继续 | `@log.warn() + return` | 警告但不中断 |
| 下载/解压失败 | `raise fail()` | 必须中断 |
| 网络临时问题 | 自动重试，最终失败再 `raise fail()` | 容错优先 |

### URL 校验方案

在 `config set` 命令处理中增加校验：
- URL 类值必须以 `http://` 或 `https://` 开头
- `github_proxy` 值应包含 `$URL` 变量（用于替换原始链接）
- `node_mirror` 值不应包含 `$URL`（是直接替换前缀）

### 下载重试方案

在 `download_file` 和 `download` 函数中包装重试逻辑：
- 最大重试次数：3
- 间隔策略：1s → 3s → 5s（递增）
- 仅对网络级错误重试（连接失败、超时），不对 4xx/5xx HTTP 错误重试
- 每次重试时记录日志：`@log.warn("下载失败，第 N 次重试...")`

## Risks / Trade-offs

- **文件拆分风险**：`tool.mbt` 拆分后，`moon.pkg` 和对外 `pub using` 需精确同步，遗漏会导致编译失败
- **错误处理统一风险**：将部分 `@log.error() + return` 改为 `raise fail()` 可能改变命令的退出行为，需逐个确认不影响用户体验
- **URL 校验风险**：过度校验可能阻止合法的自定义配置（如本地 HTTP 服务器），校验规则需宽松
- **下载重试风险**：重试会增加最大等待时间（3 次 = 额外约 9 秒），但对用户来说是透明改善
