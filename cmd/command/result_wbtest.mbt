test "CommandResult::success 创建成功结果" {
  let result = CommandResult::success()
  debug_inspect(
    result,
    content=(
      #|{ output: "", exit_code: 0, error: None }
    ),
  )
}

test "CommandResult::success_with_output 创建带输出的成功结果" {
  let result = CommandResult::success_with_output("v0.0.1")
  debug_inspect(
    result,
    content=(
      #|{ output: "v0.0.1", exit_code: 0, error: None }
    ),
  )
}

test "CommandResult::failure 创建失败结果（默认退出码）" {
  let result = CommandResult::failure("未安装")
  debug_inspect(
    result,
    content=(
      #|{ output: "", exit_code: 1, error: Some("未安装") }
    ),
  )
}

test "CommandResult::failure 创建失败结果（指定退出码）" {
  let result = CommandResult::failure("参数错误", exit_code=2)
  debug_inspect(
    result,
    content=(
      #|{ output: "", exit_code: 2, error: Some("参数错误") }
    ),
  )
}

test "CommandResult::write 追加输出内容" {
  let result = CommandResult::success()
  result.write("hello\n")
  result.write("world\n")
  debug_inspect(
    result,
    content=(
      #|{ output: "hello\nworld\n", exit_code: 0, error: None }
    ),
  )
}

test "CommandResult::is_success 判断是否成功" {
  let ok = CommandResult::success()
  debug_inspect(
    ok.is_success(),
    content=(
      #|true
    ),
  )
  let fail = CommandResult::failure("错误")
  debug_inspect(
    fail.is_success(),
    content=(
      #|false
    ),
  )
}

test "print_to 同时打印并捕获" {
  let result = CommandResult::success()
  print_to(result, "hello")
  print_to(result, "world")
  debug_inspect(
    result,
    content=(
      #|{ output: "hello\nworld\n", exit_code: 0, error: None }
    ),
  )
}

async test "run 空参数返回 CommandResult::failure" {
  let result = run(Run(Node, "", []))
  debug_inspect(
    result.is_success(),
    content=(
      #|false
    ),
  )
  debug_inspect(
    result.output.is_blank(),
    content=(
      #|true
    ),
  )
  assert_true(result.error is Some(_))
}
