## 1. 纯输出命令测试

- [x] 1.1 新增 ConfigList 测试：验证 exit_code=0、output 包含配置项关键字、error=None
- [x] 1.2 新增 UpgradeList 测试：验证 exit_code=0、output 包含版本号格式
- [x] 1.3 新增 CacheClean 测试：验证 exit_code=0、output 包含清理结果信息
- [x] 1.4 新增 Current(None) 测试：验证 exit_code=0 或 exit_code!=0 两种情况、output 包含当前版本信息或 error 包含提示

## 2. 需要本地环境的命令测试

- [x] 2.1 新增 List(None) 测试：验证 exit_code=0、output 包含工具列表格式
- [x] 2.2 新增 List(Some(Node)) 测试：验证 exit_code=0、output 包含 Node 版本列表
- [x] 2.3 新增 Which(Node) 测试：验证 exit_code=0 且 output 包含路径，或 exit_code!=0

## 3. Run 命令核心测试

- [x] 3.1 新增 Run node -v 测试：验证 exit_code=0、plain_output() 包含版本号格式（"v" 开头）
- [x] 3.2 新增 Run npm -v 测试：验证 exit_code=0、plain_output() 包含数字版本号
- [x] 3.3 新增 Run npx -v 测试：验证 exit_code=0、plain_output() 包含数字版本号
- [x] 3.4 新增 Run bunx -v 测试：验证 exit_code=0 或 exit_code!=0（Bun 可能未安装）
- [x] 3.5 新增 Run rustc --version 测试：验证 exit_code=0、plain_output() 包含 "rustc"（注意：rustc -v 无效，改用 --version）
- [x] 3.6 新增 Run go version 测试：验证 exit_code=0、plain_output() 包含 "go"
- [x] 3.7 新增 Run deno -V 测试：验证 exit_code=0 且 plain_output() 包含 "deno"，或 exit_code!=0
- [x] 3.8 新增 Run python3 -V 测试：验证 exit_code=0 且 plain_output() 包含 "Python"，或 exit_code!=0
- [x] 3.9 新增 Run java -version 测试：验证 exit_code=0 且 output 包含版本信息，或 exit_code!=0
- [x] 3.10 新增 Run kotlin -version 测试：验证 exit_code=0 且 plain_output() 包含版本信息，或 exit_code!=0
- [x] 3.11 新增 Run zig version 测试：验证 exit_code=0 且 plain_output() 包含版本号，或 exit_code!=0
- [x] 3.12 新增 Run 不存在程序测试：验证 CommandResult 为 failure（error 不为 None）
- [x] 3.13 新增 Run 空参数测试：验证 CommandResult 为 failure、error 包含提示信息
- [x] 3.14 新增 Run 指定版本号测试：验证 exit_code=0 且 plain_output() 包含版本号，或 exit_code!=0

## 4. 验证与整理

- [x] 4.1 运行 `moon test` 确保所有新增测试通过（134/134 通过）
- [x] 4.2 运行 `moon check` 确保无新增警告（0 错误 0 警告）
- [x] 4.3 检查测试代码风格与现有测试一致（分组注释、断言模式）
