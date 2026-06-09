///|
/// 将可能抛出异常的表达式转换为 Result 类型
/// 成功时返回 Ok(value)，失败时返回 Err(error)
///
/// 示例：
/// ```moonbit nocheck
/// // 原来的 try?
/// guard (try? some_function()) is Ok(value)
///
/// // 使用 to_result
/// guard to_result(() => some_function()) is Ok(value)
/// ```
pub fn[T] to_result(f : () -> T raise) -> Result[T, Error] {
  Ok(f()) catch {
    e => Err(e)
  }
}
