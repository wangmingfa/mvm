## ADDED Requirements

### Requirement: 关键路径测试覆盖补充

为项目中的关键逻辑补充单元测试，确保核心功能的稳定性。

#### Scenario: 下载重试逻辑测试
- **WHEN** 查看 `request/download.mbt` 中的测试
- **THEN** 包含测试验证重试机制的行为（模拟失败场景后重试成功）

#### Scenario: URL 校验函数测试
- **WHEN** 查看 `cmd/command/config.mbt` 中的测试
- **THEN** 包含测试验证各种 URL 格式的校验结果：
  - 有效 URL（以 https:// 开头）
  - 无效 URL（不以 http/https 开头）
  - github_proxy 包含 $URL 的情况
  - github_proxy 缺少 $URL 的警告情况

#### Scenario: 错误处理模式测试
- **WHEN** 查看各命令模块的测试
- **THEN** 包含测试验证错误处理行为的一致性：
  - 参数错误时 raise fail
  - 版本已安装时 warn + return

#### Scenario: cache.mbt 测试
- **WHEN** 查看 `tool_def/cache.mbt` 中的测试
- **THEN** 包含测试验证缓存读写逻辑：
  - no_cache 模式下 read_cache_file_content 返回 None
  - 正常模式下读取缓存文件

#### Scenario: url.mbt 测试
- **WHEN** 查看 `tool_def/url.mbt` 中的测试
- **THEN** 已有 replace_url 测试迁移到此文件
- **THEN** apply_global_config 的各分支（node_mirror、go_mirror、github_proxy）均有测试覆盖
