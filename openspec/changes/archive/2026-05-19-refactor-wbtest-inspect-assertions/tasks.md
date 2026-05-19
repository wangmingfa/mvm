## 1. 新增辅助函数

- [x] 1.1 在 `mvm_wbtest.mbt` 中添加 `get_mvm_version` 函数，读取项目根目录 `mvm.json` 并返回指定工具版本号
- [x] 1.2 确认测试包的 `moon.pkg.json` 已包含必要的依赖（`@fs`、`@fs_ext`、`@env`、`@json` 等）

## 2. 替换 assert_true 为 inspect（精确值场景）

- [x] 2.1 "run 不存在的程序返回 failure" 测试：将 `assert_true(!result.is_success())` 改为 `inspect(result.is_success(), content=(#|false))`
- [x] 2.2 "run 不存在的程序返回 failure" 测试：将 `assert_true(result.error is Some(_))` 改为 `inspect(result.error is Some(_), content=(#|true))`
- [x] 2.3 "run 空参数返回 failure" 测试：将 `assert_true(!result.is_success())` 改为 `inspect(result.is_success(), content=(#|false))`
- [x] 2.4 "run 空参数返回 failure" 测试：将 match + `assert_true(msg.contains("不能为空"))` 改为 `inspect` 精确匹配 error 内容

## 3. 版本号测试改用 mvm.json 数据驱动

- [x] 3.1 "run node -v" 测试：从 `mvm.json` 读取 node 版本号，成功时用 `guard` 替代 `assert_true(contains("v"))`
- [x] 3.2 "run zig version" 测试：从 `mvm.json` 读取 zig 版本号，成功时用 `guard` 替代 `assert_true(length() > 0)`
- [x] 3.3 "run go version" 测试：从 `mvm.json` 读取 go 版本号，成功时验证 `plain_output()` 包含 `go` + 版本号
- [x] 3.4 "run deno -V" 测试：从 `mvm.json` 读取 deno 版本号，成功时验证 `plain_output()` 包含版本号核心部分
- [x] 3.5 "run java -version" 测试：从 `mvm.json` 读取 java 版本号，成功时验证 `plain_output()` 包含版本号
- [x] 3.6 "run bunx -v" 测试：从 `mvm.json` 读取 bun 版本号，成功时精确或包含对比版本号
- [x] 3.7 "run kotlin -version" 测试：将 `assert_true(plain_output().length() > 0)` 改为更精确的断言（条件性，mvm.json 中无 kotlin 版本号）
- [x] 3.8 "run rustc --version" 测试：保留 `contains("rustc")` 断言（mvm.json 中版本号仅为 v1），但改用 `inspect` 对 `is_success()` 等精确值

## 4. 动态输出场景优化

- [x] 4.1 "help 命令" 测试：将 `assert_true(result.output.contains("mvm"))` 改为 `assert_true(result.plain_output().contains("mvm"))`，去除 ANSI 颜色干扰
- [x] 4.2 "config list" 测试：将 `assert_true(result.output.contains(...))` 改为 `assert_true(result.plain_output().contains(...))`
- [x] 4.3 "upgrade list" 测试：将 `assert_true(result.output.length() > 0)` 改为 `assert_true(result.plain_output().length() > 0)`，并对环境依赖值改用 `guard` 替代 `inspect`
- [x] 4.4 "cache clean" 测试：将 `assert_true(result.output.length() > 0)` 改为 `assert_true(result.plain_output().length() > 0)`，并对环境依赖值改用 `guard` 替代 `inspect`
- [x] 4.5 "current 命令" 测试：将 `assert_true(result.output.length() > 0)` 改为 `assert_true(result.plain_output().length() > 0)`
- [x] 4.6 "list 命令" 测试：将 `assert_true(result.output.length() > 0)` 改为对 `plain_output()` 的断言

## 5. 运行验证

- [x] 5.1 运行 `moon test --target native` 验证所有测试通过（134/134 passed）
- [x] 5.2 检查 linter 错误，确保无新增警告（0 warnings, 0 errors）
