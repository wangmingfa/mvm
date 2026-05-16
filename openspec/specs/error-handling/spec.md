## CHANGED Requirements

### Requirement: 错误处理模式统一

所有命令执行中的错误处理遵循统一约定，确保用户获得一致的体验。

#### Scenario: 命令参数错误时中断执行
- **WHEN** 用户传入无效参数（如 `mvm pin node` 缺少版本号）
- **THEN** 使用 `raise fail()` 抛出错误，程序中断并显示中文错误提示

#### Scenario: 版本已安装时提示但不中断
- **WHEN** 用户执行 `mvm install node@20`，但 `node@20` 已安装
- **THEN** 使用 `@log.warn()` 输出提示信息，函数 `return` 结束（不中断进程）

#### Scenario: 下载失败时中断并提示
- **WHEN** 文件下载失败（网络错误、HTTP 5xx）
- **THEN** 使用 `raise fail()` 抛出错误，中断安装流程

#### Scenario: 下载临时失败时自动重试
- **WHEN** 下载过程中遇到网络临时错误（连接超时、DNS 解析失败）
- **THEN** 自动重试最多 3 次，间隔 1s → 3s → 5s，每次重试前输出 `@log.warn("下载失败，第 N 次重试...")`
- **THEN** 重试全部失败后 `raise fail()` 中断

#### Scenario: SHA256 校验失败时重试
- **WHEN** 下载文件 SHA256 校验失败
- **THEN** 清除损坏文件，重新下载（不使用缓存），再次校验
- **THEN** 重试后仍失败则 `raise fail()` 中断并提示检查网络或使用 `--skip-verify`

#### Scenario: 非关键路径缺失时警告
- **WHEN** 某个可选文件或目录不存在但不影响主流程（如缓存目录为空）
- **THEN** 使用 `@log.warn()` 提示，继续执行
