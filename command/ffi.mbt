///|
/// 子进程运行结果：同时包含退出码和捕获的 stdout 输出
pub struct RunOutput {
  /// 退出码（0 表示成功）
  exit_code : Int
  /// 捕获的 stdout 输出（UTF-8 解码后的字符串）
  output : String
} derive(Debug)

///|
/// C FFI 声明：通过 fork + execvp + pipe 执行子进程
/// 同时流式输出到控制台并捕获 stdout
/// args_packed: null-delimited packed 字符串（"cmd\0arg1\0arg2\0\0"）
/// envs_packed: null-delimited packed 环境变量（"KEY=VAL\0KEY2=VAL2\0\0"）
/// 返回: [4字节 big-endian exit_code][output bytes]
#borrow(args_packed, envs_packed)
extern "c" fn mvm_run_with_output(
  args_packed : Bytes,
  envs_packed : Bytes,
) -> Bytes = "mvm_run_with_output"

///|
/// 执行子进程并同时流式输出到控制台 + 捕获 stdout
/// 仅在 native 目标可用（依赖 C FFI mvm_run_with_output）
pub fn run_with_output(
  cmd : String,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
) -> RunOutput {
  let (cmd, args) = get_cmd_and_args(cmd, args)
  let arg_str = join_args(args)
  @log.debug("运行(捕获输出): \{cmd} \{arg_str}")
  let args_packed = pack_args(cmd, args)
  let envs_packed = pack_envs(extra_env)
  let raw = mvm_run_with_output(args_packed, envs_packed)
  unpack_run_result(raw)
}

///|
/// 将 cmd + args 打包为 null-delimited 格式
/// 格式: "cmd\0arg1\0arg2\0\0" (双 null 结尾)
fn pack_args(cmd : String, args : ArrayView[String]) -> Bytes {
  let mut buf = @ffi.string_to_c_bytes(cmd)
  for arg in args {
    buf = buf + @ffi.string_to_c_bytes(arg)
  }
  // 添加结尾的额外 null 字节（双 null 终止）
  buf + Bytes::from_array([0])
}

///|
/// 将环境变量 Map 打包为 null-delimited KEY=VALUE 格式
/// 格式: "KEY=VAL\0KEY2=VAL2\0\0" (双 null 终止)
fn pack_envs(envs : Map[String, String]) -> Bytes {
  if envs.is_empty() {
    return Bytes::from_array([0])
  }
  let entries : Array[Bytes] = []
  envs.each(fn(key, val) {
    entries.push(@ffi.string_to_c_bytes("\{key}=\{val}"))
  })
  let mut buf = Bytes::from_array([])
  for entry in entries {
    buf = buf + entry
  }
  buf + Bytes::from_array([0])
}

///|
/// 从 C FFI 返回的 Bytes 解包为 RunOutput
/// 返回格式: [4字节 big-endian exit_code][output bytes]
fn unpack_run_result(raw : Bytes) -> RunOutput {
  // 读取 big-endian 4字节 exit_code
  let exit_code = (raw[0].to_int() << 24) |
    (raw[1].to_int() << 16) |
    (raw[2].to_int() << 8) |
    raw[3].to_int()
  // 处理负数 (big-endian 中最高位为符号位)
  let exit_code = if exit_code > 127 { exit_code - 256 } else { exit_code }
  // 解码 UTF-8 output bytes (从第 5 字节开始)
  let output = if raw.length() > 4 { @utf8.decode_lossy(raw[4:]) } else { "" }
  RunOutput::{ exit_code, output }
}

///|
test "ffi_run_with_output_echo" {
  let result = run_with_output("echo", ["hello"])
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  assert_true(result.output.contains("hello"))
}

///|
test "ffi_run_with_output_multi_args" {
  let result = run_with_output("echo", ["hello", "world"])
  inspect(
    result.exit_code,
    content=(
      #|0
    ),
  )
  assert_true(result.output.contains("hello"))
  assert_true(result.output.contains("world"))
}

///|
test "ffi_run_with_output_exit_code" {
  // false 命令总是返回退出码 1
  let result = run_with_output("false", [])
  assert_true(result.exit_code != 0)
}

///|
test "ffi_pack_args_format" {
  // 验证 pack_args 生成正确的 null-delimited 格式
  let packed = pack_args("cmd", ["arg1", "arg2"])
  // "cmd\0arg1\0arg2\0\0" - 每个 string_to_c_bytes 添加 null，最后再加一个 null
  let expected = @ffi.string_to_c_bytes("cmd") +
    @ffi.string_to_c_bytes("arg1") +
    @ffi.string_to_c_bytes("arg2") +
    Bytes::from_array([0])
  assert_eq(packed, expected)
}

///|
test "ffi_pack_envs_empty" {
  // 空 envs 应返回单个 null 字节
  let packed = pack_envs({})
  inspect(
    packed.length(),
    content=(
      #|1
    ),
  )
}

///|
test "ffi_pack_envs_nonempty" {
  let packed = pack_envs({ "KEY": "VAL" })
  // "KEY=VAL\0\0" - string_to_c_bytes("KEY=VAL") adds null, then trailing null
  let expected = @ffi.string_to_c_bytes("KEY=VAL") + Bytes::from_array([0])
  assert_eq(packed, expected)
}

///|
test "ffi_unpack_run_result_success" {
  // 模拟成功结果: exit_code=0 (big-endian 4字节), output="hello\n"
  let output_bytes = @utf8.encode("hello\n")
  let raw = Bytes::from_array([0, 0, 0, 0]) + output_bytes
  let result = unpack_run_result(raw)
  debug_inspect(
    result,
    content=(
      #|{ exit_code: 0, output: "hello\n" }
    ),
  )
}

///|
test "ffi_unpack_run_result_failure" {
  // 模拟失败结果: exit_code=1 (big-endian 4字节), output=""
  let raw = Bytes::from_array([0, 0, 0, 1])
  let result = unpack_run_result(raw)
  debug_inspect(
    result,
    content=(
      #|{ exit_code: 1, output: "" }
    ),
  )
}
