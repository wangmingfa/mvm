## MODIFIED Requirements

### Requirement: 白盒测试断言使用 inspect/content 模式

当前 `mvm_wbtest.mbt` 中对可确定预期值的场景使用了 `assert_true` 模糊断言。应改为 `inspect` / `debug_inspect` + `content` 参数精确断言，使测试失败时展示 diff 对比。

**Scenario: exit_code 断言**
- **WHEN** 测试验证 `CommandResult.exit_code` 值
- **THEN** 使用 `inspect(result.exit_code, content=(#|0))` 或 `inspect(result.exit_code, content=(#|1))`

**Scenario: is_success 断言**
- **WHEN** 测试验证 `CommandResult.is_success()` 返回值
- **THEN** 使用 `inspect(result.is_success(), content=(#|true))` 或 `inspect(result.is_success(), content=(#|false))`

**Scenario: error 断言**
- **WHEN** 测试验证 `CommandResult.error` 为 None
- **THEN** 使用 `debug_inspect(result.error, content=(#|None))`
- **WHEN** 测试验证 `CommandResult.error` 为 Some 且包含特定消息
- **THEN** 使用 `debug_inspect(result.error, content=(#|Some("...")))` 或检查消息内容

**Scenario: 失败场景断言**
- **WHEN** 测试验证命令失败（`!result.is_success()`）
- **THEN** 使用 `inspect(result.is_success(), content=(#|false))` 代替 `assert_true(!result.is_success())`
- **WHEN** 测试验证 error 为 Some
- **THEN** 使用 `debug_inspect(result.error, content=(#|Some("...")))` 代替 `assert_true(result.error is Some(_))`

**Scenario: 错误消息断言**
- **WHEN** 测试验证错误消息包含特定关键字
- **THEN** 优先使用 `debug_inspect` 对 error 做精确值断言，若消息格式不确定则保留 `assert_true`

### Requirement: 版本号测试从 mvm.json 数据驱动

运行工具 `-v` 命令的测试应从项目根目录 `mvm.json` 读取对应工具的版本号，用 `inspect` 将 `plain_output()` 与版本号进行对比。

**Scenario: Node 版本号精确对比**
- **WHEN** 运行 `node -v` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `node` 版本号，使用 `inspect(result.plain_output(), content=(#|版本号))` 精确对比

**Scenario: Zig 版本号精确对比**
- **WHEN** 运行 `zig version` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `zig` 版本号，使用 `inspect(result.plain_output(), content=(#|版本号))` 精确对比

**Scenario: Go 版本号包含对比**
- **WHEN** 运行 `go version` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `go` 版本号，验证 `plain_output()` 包含 `go` 和版本号

**Scenario: Deno 版本号包含对比**
- **WHEN** 运行 `deno -V` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `deno` 版本号，验证 `plain_output()` 包含版本号核心部分

**Scenario: Java 版本号包含对比**
- **WHEN** 运行 `java -version` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `java` 版本号，验证 `plain_output()` 包含版本号

**Scenario: Bun 版本号精确对比（条件性）**
- **WHEN** 运行 `bunx -v` 命令且命令成功
- **THEN** 从 `mvm.json` 读取 `bun` 版本号，使用 `inspect` 精确或包含对比

**Scenario: Rust 版本号模糊对比**
- **WHEN** 运行 `rustc --version` 命令且命令成功
- **THEN** 保留 `contains("rustc")` 断言（`mvm.json` 中 rust 版本号仅为 `v1`，不够精确）

**Scenario: npm/npx 版本号（无 mvm.json 数据）**
- **WHEN** 运行 `npm -v` 或 `npx -v` 命令且命令成功
- **THEN** 保留当前硬编码版本号断言（npm 版本号不在 `mvm.json` 中）

**Scenario: 未安装工具容错**
- **WHEN** 运行某工具版本命令但工具未安装导致失败
- **THEN** 不做版本号断言，仅验证 `exit_code` 和 `is_success()` 状态

## ADDED Requirements

### Requirement: mvm.json 版本号读取辅助函数

新增辅助函数 `get_mvm_version` 用于在测试中读取项目 `mvm.json` 的工具版本号。

**Scenario: 正常读取版本号**
- **WHEN** `mvm.json` 存在且包含指定工具的版本号
- **THEN** 返回对应版本号字符串（如 `v24.15.0`、`1.26.3`）

**Scenario: mvm.json 不存在或格式错误**
- **WHEN** `mvm.json` 不存在或 JSON 格式无效
- **THEN** raise fail 报错

**Scenario: 工具名不存在于 mvm.json**
- **WHEN** `mvm.json` 中无指定工具的键
- **THEN** raise fail 报错

## UNCHANGED Requirements

### Requirement: 动态输出场景保留模糊断言

对于无法确定精确预期值的场景（帮助文本、配置列表、版本列表），保留 `assert_true` 模式：

- **帮助命令输出**：使用 `plain_output()` 去除 ANSI 后用 `assert_true(contains(...))` 检查关键字
- **配置列表输出**：保留 `assert_true(contains("github_proxy") || contains("registry"))`
- **版本列表非空**：保留 `assert_true(output.length() > 0)` 或改为 `inspect(exit_code)` + 保留模糊输出断言
- **Cache/Current 等不确定输出**：保留条件断言
