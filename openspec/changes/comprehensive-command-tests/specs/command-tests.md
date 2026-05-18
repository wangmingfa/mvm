## ADDED Requirements

### Requirement: 纯输出命令白盒测试
所有不依赖本地环境状态的命令应返回正确的 CommandResult。

- **Scenario: Version 命令**
  - **WHEN** run(Command::Version)
  - **THEN** exit_code=0, output 以 "v" 开头并换行结尾, error=None, is_success()=true

- **Scenario: Help 命令**
  - **WHEN** run(Command::Help)
  - **THEN** exit_code=0, output 包含 "mvm" 和 "命令", error=None, is_success()=true

- **Scenario: ConfigList 命令**
  - **WHEN** run(Command::ConfigList)
  - **THEN** exit_code=0, output 包含配置项关键字, error=None

- **Scenario: UpgradeList 命令**
  - **WHEN** run(Command::UpgradeList)
  - **THEN** exit_code=0, output 包含版本列表格式（数字版本号）

- **Scenario: CacheClean 命令**
  - **WHEN** run(Command::CacheClean)
  - **THEN** exit_code=0, output 包含清理结果信息

- **Scenario: Current 全部工具**
  - **WHEN** run(Command::Current(None))
  - **THEN** exit_code=0 或 exit_code!=0（无已使用工具时可能报错）

- **Scenario: Current 指定工具**
  - **WHEN** run(Command::Current(Some(Node)))
  - **THEN** exit_code=0 且 output 包含版本号，或 exit_code!=0（Node 未使用时）

### Requirement: 需要本地环境的命令白盒测试
依赖本地 mvm 安装状态的命令应返回合理结果，测试容许成功/失败两种情况。

- **Scenario: List 全部工具**
  - **WHEN** run(Command::List(None))
  - **THEN** exit_code=0, output 包含工具列表格式

- **Scenario: List 指定工具**
  - **WHEN** run(Command::List(Some(Node)))
  - **THEN** exit_code=0, output 包含 Node 已安装版本列表

- **Scenario: Which 指定工具**
  - **WHEN** run(Command::Which(Node))
  - **THEN** exit_code=0 且 output 包含路径，或 exit_code!=0（未安装时）

### Requirement: Run 命令白盒测试（核心重点）
Run 命令应正确代理执行外部工具并捕获 stdout，对常用工具验证端到端可靠性。

- **Scenario: Run node -v**
  - **WHEN** run(Command::Run(Node, "", ["node", "-v"]))
  - **THEN** exit_code=0, plain_output() 包含版本号格式 (如 "v22.x.x")

- **Scenario: Run npm -v**
  - **WHEN** run(Command::Run(Node, "", ["npm", "-v"]))
  - **THEN** exit_code=0, plain_output() 包含数字版本号

- **Scenario: Run npx -v**
  - **WHEN** run(Command::Run(Node, "", ["npx", "-v"]))
  - **THEN** exit_code=0, plain_output() 包含数字版本号

- **Scenario: Run bunx -v**
  - **WHEN** run(Command::Run(Bun, "", ["bunx", "-v"]))
  - **THEN** exit_code=0 且 output 包含版本号，或 exit_code!=0（Bun 未安装时）

- **Scenario: Run rustc -v**
  - **WHEN** run(Command::Run(Rust, "", ["rustc", "-v"]))
  - **THEN** exit_code=0, plain_output() 包含 "rustc"

- **Scenario: Run go version**
  - **WHEN** run(Command::Run(Go, "", ["go", "version"]))
  - **THEN** exit_code=0, plain_output() 包含 "go"

- **Scenario: Run deno -v**
  - **WHEN** run(Command::Run(Deno, "", ["deno", "-V"]))
  - **THEN** exit_code=0 且 plain_output() 包含 "deno"，或 exit_code!=0（Deno 未安装时）

- **Scenario: Run python3 -V**
  - **WHEN** run(Command::Run(Python, "", ["python3", "-V"]))
  - **THEN** exit_code=0 且 plain_output() 包含 "Python"，或 exit_code!=0（Python 未安装时）

- **Scenario: Run java -version**
  - **WHEN** run(Command::Run(Java, "", ["java", "-version"]))
  - **THEN** exit_code=0 且 output 包含版本信息，或 exit_code!=0（Java 未安装时）

- **Scenario: Run kotlin -version**
  - **WHEN** run(Command::Run(Kotlin, "", ["kotlin", "-version"]))
  - **THEN** exit_code=0 且 plain_output() 包含版本信息，或 exit_code!=0（Kotlin 未安装时）

- **Scenario: Run zig version**
  - **WHEN** run(Command::Run(Zig, "", ["zig", "version"]))
  - **THEN** exit_code=0 且 plain_output() 包含版本号，或 exit_code!=0（Zig 未安装时）

- **Scenario: Run 不存在的程序**
  - **WHEN** run(Command::Run(Node, "", ["nonexistent_program"]))
  - **THEN** CommandResult 为 failure（exit_code!=0 或 error 不为 None）

- **Scenario: Run 空参数**
  - **WHEN** run(Command::Run(Node, "", []))
  - **THEN** CommandResult 为 failure，error 包含提示信息

- **Scenario: Run 指定版本号**
  - **WHEN** run(Command::Run(Node, "22", ["node", "-v"]))
  - **THEN** exit_code=0 且 plain_output() 包含版本号，或 exit_code!=0（版本 22 未安装时）

### Requirement: 断言模式规范
所有白盒测试应遵循统一的断言模式，与现有测试风格一致。

- **Scenario: Int 类型断言**
  - **WHEN** 验证 exit_code（Int 类型）
  - **THEN** 使用 `inspect` 精确匹配预期值

- **Scenario: String 类型确定性断言**
  - **WHEN** 验证 output（String 类型）且内容确定
  - **THEN** 使用 `inspect` 精确匹配

- **Scenario: String 类型动态断言**
  - **WHEN** 验证 output 且内容依赖环境（版本号等动态值）
  - **THEN** 使用 `plain_output()` + `assert_true(.contains())` 匹配关键字

- **Scenario: Option 类型断言**
  - **WHEN** 验证 error（String? 类型）
  - **THEN** 使用 `debug_inspect`（Option 的 Debug 表示为 None 或 Some("...")）

- **Scenario: Bool 类型断言**
  - **WHEN** 验证 is_success()（Bool 类型）
  - **THEN** 使用 `inspect` 精确匹配