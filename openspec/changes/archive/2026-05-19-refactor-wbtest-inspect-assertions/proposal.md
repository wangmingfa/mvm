## Why

当前 `mvm_wbtest.mbt` 白盒测试文件中大量使用 `assert_true` 进行断言（如 `assert_true(result.output.contains("mvm"))`、`assert_true(result.output.length() > 0)`），这类断言仅能验证"存在性"或"非空"，无法表达精确的预期值，测试失败时也无法直接看到期望与实际的差异。

MoonBit 的 `inspect` / `debug_inspect` 函数配合 `content` 参数，可以声明式地写明预期输出值，测试失败时会自动展示 diff 对比，使断言更精确、更易调试。

此外，对于 `Run` 命令中运行工具 `-v` 版本号命令的测试（如 `node -v`、`npm -v`、`go version`），当前做法是硬编码版本号或用 `assert_true(result.plain_output().contains("v"))` 等模糊断言。更好的方式是从项目根目录的 `mvm.json` 读取对应工具的版本号，再用 `inspect` 将 `plain_output()` 与该版本号进行精确对比。

## What

1. **将 `assert_true` 断言尽可能替换为 `inspect` / `debug_inspect` + `content` 参数**：对能确定预期值的场景（exit_code、is_success、error 为 None、输出包含特定文本），改用 `inspect` 写明预期值
2. **版本号测试改用 `mvm.json` 数据驱动**：运行工具 `-v` 命令时，从 `mvm.json` 读取对应工具版本号，用 `inspect` 将 `plain_output()` 的输出与该版本号精确对比
3. **对无法确定精确预期值的场景保留合理断言**：如帮助命令输出（内容动态）、未安装工具的容错测试等，保留 `assert_true` 或 `if` 分支结构

## Impact

- **受影响文件**：`mvm_wbtest.mbt`（主要修改文件）、可能需要新增辅助函数读取 `mvm.json` 版本号
- **API 影响**：无公共 API 变化，仅修改测试代码
- **依赖**：需要 `mvm.json` 中配置对应工具版本号（当前已存在）
- **测试策略**：修改后所有测试仍应通过，且断言更精确
