///|
using @command {run, type Command}

///|
async test "version 命令返回 CommandResult" {
  let result = run(Command::Version)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  inspect(
    result.output,
    content=(
      #|v0.0.1
      #|
    ),
  )
  inspect(
    result.is_success(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    result.error,
    content=(
      #|None
    ),
  )
}

///|
async test "help 命令返回 CommandResult" {
  let result = run(Command::Help)
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  assert_true(result.output.contains("mvm"))
  assert_true(result.output.contains("命令"))
  inspect(
    result.is_success(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    result.error,
    content=(
      #|None
    ),
  )
}
