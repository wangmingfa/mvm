## Context

当前 `mvm_wbtest.mbt` 是项目的白盒测试文件，共 360 行，包含 18 个测试用例。测试中混用了三种断言模式：

1. **`inspect` + `content` 参数**：用于精确值断言（如 `exit_code`、`is_success()`、`error`）
2. **`debug_inspect` + `content` 参数**：用于 Optional 值断言（如 `result.error`）
3. **`assert_true`**：用于模糊断言（如 `contains("mvm")`、`length() > 0`、`contains("v")`）

版本号相关测试存在两个问题：
- 硬编码版本号（如 `npm -v` 测试中 `inspect` 写了 `#|11.12.1`），环境变化时测试会失败
- 用模糊断言（如 `contains("v")`、`contains("rustc")`），无法验证版本号是否正确

项目根目录的 `mvm.json` 存储了各工具的版本号配置：
```json
{
  "node": "v24.15.0",
  "bun": "v1.3.14",
  "zig": "0.16.0",
  "rust": "v1",
  "java": "20",
  "go": "1.26.3",
  "deno": "v2.7.14"
}
```

已有 `@tools` 包提供 `Config` 结构体和 `get_config` 函数可读取 `mvm.json`，但测试中未使用。

## Goals / Non-Goals

**Goals:**
- 将所有能确定预期值的 `assert_true` 断言改为 `inspect` / `debug_inspect` + `content` 参数
- 版本号测试从 `mvm.json` 读取预期版本号，用 `inspect` 将 `plain_output()` 与之对比
- 保持测试的可移植性（不同环境下版本号不同时，从 `mvm.json` 动态读取）

**Non-Goals:**
- 不修改 `@command` 或 `@tools` 包的生产代码
- 不改变测试用例的数量或整体结构
- 不对帮助文本、配置列表等动态输出内容做精确值断言（这些内容随版本变化，不适合写死）
- 不处理 npm/npx 版本号的精确断言（npm 版本号不在 `mvm.json` 中单独存储，随 node 版本变化）

## Design

### 1. 新增测试辅助函数：读取 `mvm.json` 版本号

在 `mvm_wbtest.mbt` 中新增辅助函数 `get_mvm_version`，直接读取项目根目录的 `mvm.json` 并提取指定工具的版本号：

```moonbit
fn get_mvm_version(tool_name : String) -> String raise {
  let mvm_path = @fs_ext.join_path(@env.current_dir()!, "mvm.json")
  let content = @fs.read_file(mvm_path)
  let json = content.json()
  guard json is Object(map) else { raise fail("mvm.json 格式错误") }
  guard map.get(tool_name) is Some(String(version)) else {
    raise fail("mvm.json 中未找到 \{tool_name} 的版本号")
  }
  version
}
```

**设计决策**：直接用 `@fs.read_file` 读取而非 `@tools.get_config`，原因：
- `get_config` 搜索逻辑会向上查找父目录，在测试环境中路径不确定
- 测试需要读取的是项目根目录的特定 `mvm.json`，而非用户全局配置
- 直接读取更简单、路径可控

### 2. 断言替换策略

按场景分类处理：

| 场景 | 当前断言 | 改进方式 | 说明 |
|------|---------|---------|------|
| `exit_code` | 已用 `inspect` | 保持不变 | 已符合规范 |
| `is_success()` | 已用 `inspect` | 保持不变 | 已符合规范 |
| `error` 为 None | 已用 `debug_inspect` | 保持不变 | 已符合规范 |
| 帮助文本包含关键字 | `assert_true(result.output.contains("mvm"))` | `inspect(result.output, content=(#|...))` 模式 | 帮助文本是动态的，改用多行 content 匹配关键行 |
| 配置列表包含关键字 | `assert_true(contains("github_proxy") || contains("registry"))` | 保留 `assert_true` | 输出格式不确定，无法写精确值 |
| 版本列表非空 | `assert_true(result.output.length() > 0)` | 保留 `assert_true` | 内容动态变化 |
| 版本号 `-v` 命令 | `assert_true(plain_output().contains("v"))` 或硬编码 | `inspect(plain_output(), content=(#|版本号))` | 从 `mvm.json` 动态读取 |
| 失败场景（`!is_success`） | `assert_true(!result.is_success())` | `inspect(result.is_success(), content=(#|false))` | 精确值可确定 |
| error 为 Some | `assert_true(result.error is Some(_))` | `debug_inspect(result.error, content=(#|Some(...)))` | 需要注意 error 消息内容 |
| 错误消息包含关键字 | `assert_true(msg.contains("不能为空"))` | 改用 `inspect` 或 `debug_inspect` 精确匹配 | 错误消息是固定的 |

### 3. 版本号对比设计

不同工具的 `-v` 输出格式不同：

| 工具 | 命令 | 输出格式 | mvm.json 值 | 对比策略 |
|------|------|---------|------------|---------|
| Node | `node -v` | `v24.15.0`（纯版本号） | `v24.15.0` | `inspect(plain_output(), content=(#|版本号))` |
| npm | `npm -v` | `11.12.1`（纯数字） | 不在 mvm.json | 保留 `inspect` 硬编码或改为模糊断言 |
| npx | `npx -v` | `11.12.1`（纯数字） | 不在 mvm.json | 同 npm |
| Bun | `bunx -v` | 可能未安装 | `v1.3.14` | 成功时 `inspect(plain_output(), content=(#|版本号))` |
| Rust | `rustc --version` | `rustc 1.xx.x (xxx)` | `v1` | 成功时检查 `contains(版本号前缀)` |
| Go | `go version` | `go1.26.3 darwin/arm64` | `1.26.3` | 成功时检查 `contains("go" + 版本号)` |
| Deno | `deno -V` | `deno 2.7.14` | `v2.7.14` | 成功时检查 `contains(版本号核心部分)` |
| Python | `python3 -V` | `Python 3.xx.x` | 不在 mvm.json | 保留模糊断言 |
| Java | `java -version` | stderr 输出 | `20` | 成功时检查 `contains(版本号)` |
| Kotlin | `kotlin -version` | 动态 | 不在 mvm.json | 保留模糊断言 |
| Zig | `zig version` | `0.16.0`（纯数字） | `0.16.0` | `inspect(plain_output(), content=(#|版本号))` |

**核心策略**：对于 `mvm.json` 中有版本号且输出格式简单的工具（Node、Zig），用 `inspect` 精确对比；对于输出格式复杂或版本号模糊的工具（Rust、Go、Deno、Java），用 `inspect` 对比 `contains` 模式或保留条件断言。

### 4. 帮助命令测试改进

帮助文本输出较长且包含 ANSI 颜色码，不适合用 `content` 逐行精确匹配。改进方式：
- 使用 `plain_output()` 去除颜色码
- 用 `inspect` 对 `plain_output()` 做关键行匹配，或保留 `assert_true` 检查关键字存在

由于帮助文本格式可能随版本变化，选择保留 `assert_true(contains(...))` 模式，但改用 `plain_output()` 代替 `output` 以去除 ANSI 干扰。

## Risks / Trade-offs

- **硬编码版本号的风险**：npm/npx 版本号不在 `mvm.json` 中，保留硬编码意味着环境变化时需手动更新测试。权衡：npm 版本号随 node 版本自动确定，短期内稳定，暂保留硬编码。
- **`mvm.json` 读取路径依赖**：辅助函数依赖 `@env.current_dir()` 返回项目根目录。MoonBit 测试运行时当前目录通常是项目根目录，风险较低但需注意 CI 环境。
- **部分断言仍为模糊断言**：帮助文本、配置列表、版本列表等动态内容无法写精确值。权衡：这是合理的，这些场景用 `assert_true` 更灵活。
- **`rust` 版本号仅为 `v1`**：`mvm.json` 中 rust 版本号不够精确，无法用于精确断言 `rustc --version` 输出。权衡：保留 `contains` 断言。
