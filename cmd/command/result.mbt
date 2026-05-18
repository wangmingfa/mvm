/// 命令执行结果：替代原 Unit 返回值，使白盒测试可断言
pub(all) struct CommandResult {
  /// 标准输出内容（多条输出合并，可变字段，可追加）
  mut output : String
  /// 退出码（0 表示成功，可变字段以支持子进程退出码设置）
  mut exit_code : Int
  /// 错误信息（成功时为 None）
    error : String?
  } derive(Debug)

/// 创建成功结果（exit_code=0, error=None, output=""）
pub fn CommandResult::success() -> CommandResult {
  CommandResult::{ output: "", exit_code: 0, error: None }
}

/// 创建带输出的成功结果
pub fn CommandResult::success_with_output(msg : String) -> CommandResult {
  CommandResult::{ output: msg, exit_code: 0, error: None }
}

/// 创建失败结果，exit_code 默认为 1
pub fn CommandResult::failure(msg : String, exit_code~ : Int = 1) -> CommandResult {
  CommandResult::{ output: "", exit_code, error: Some(msg) }
}

/// 向 output 追加文本（不覆盖原有内容）
pub fn CommandResult::write(self : CommandResult, msg : String) -> Unit {
  self.output = self.output + msg
}

/// 判断是否成功（exit_code == 0）
pub fn CommandResult::is_success(self : CommandResult) -> Bool {
  self.exit_code == 0
}

/// 去除 output 中的 ANSI 颜色控制码，返回纯文本
/// 用于测试中对比文本内容，不受终端颜色干扰
pub fn CommandResult::plain_output(self : CommandResult) -> String {
  @utils.strip_colors(self.output)
}

/// 同时打印到控制台并写入 CommandResult.output
/// 替代子命令中的 println(msg)，运行时仍实时打印到控制台，result.output 同时捕获
fn print_to(result : CommandResult, msg : String) -> Unit {
  println(msg)
  result.output = result.output + msg + "\n"
}