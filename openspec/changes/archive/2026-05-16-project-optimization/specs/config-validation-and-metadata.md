## ADDED Requirements

### Requirement: config set URL 格式校验

`mvm config set` 命令对 URL 类配置值进行基础格式校验，防止用户设置无效配置。

#### Scenario: 设置有效 github_proxy
- **WHEN** 用户执行 `mvm config set github_proxy https://cdn.gh-proxy.org/$URL`
- **THEN** 校验通过：值以 `https://` 开头且包含 `$URL` 变量
- **THEN** 配置成功保存

#### Scenario: 设置缺少 $URL 的 github_proxy
- **WHEN** 用户执行 `mvm config set github_proxy https://cdn.gh-proxy.org/`
- **THEN** 校验失败：github_proxy 值应包含 `$URL` 变量以替换原始链接
- **THEN** 输出警告提示 `@log.warn("github_proxy 配置通常需要包含 $URL 变量来替换原始链接")`
- **THEN** 仍然保存配置（宽松校验，不阻断）

#### Scenario: 设置无效 URL 格式
- **WHEN** 用户执行 `mvm config set github_proxy not-a-url`
- **THEN** 校验失败：值不以 `http://` 或 `https://` 开头
- **THEN** 使用 `raise fail()` 中断并提示："URL 配置值应以 http:// 或 https:// 开头"

#### Scenario: 设置有效 node_mirror
- **WHEN** 用户执行 `mvm config set node_mirror https://mirrors.aliyun.com/nodejs-release`
- **THEN** 校验通过：值以 `https://` 开头
- **THEN** 配置成功保存

#### Scenario: 设置预设配置不受校验影响
- **WHEN** 用户执行 `mvm config set china`
- **THEN** 预设配置直接应用，不触发 URL 格式校验

### Requirement: moon.mod.json 元数据补全

项目 `moon.mod.json` 中补充缺失的 description 和 keywords 字段。

#### Scenario: description 字段存在且有内容
- **WHEN** 查看 `moon.mod.json`
- **THEN** `description` 字段不为空字符串，描述项目功能（如 "Multi Version Manager - One tool to manage Node.js, Bun, Zig, Go versions"）

#### Scenario: keywords 字段包含相关标签
- **WHEN** 查看 `moon.mod.json`
- **THEN** `keywords` 字段包含至少 3 个相关标签（如 ["mvm", "version-manager", "node", "bun", "zig", "go"]）
