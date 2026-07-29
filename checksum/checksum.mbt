///|
/// C FFI: 计算文件的 SHA256 值，返回小写十六进制字符串
/// 文件打开失败时返回空字符串
#borrow(path)
extern "c" fn c_sha256_file(path : Bytes) -> String = "sha256_file"

///|
/// 计算文件的 SHA256 值
/// 使用 C FFI 实现，无需依赖外部命令（certutil/shasum/sha256sum）
fn compute_file_sha256(file_path : String) -> String raise {
  let path = @ffi.string_to_c_bytes(file_path)
  let hash = c_sha256_file(path)
  guard hash.length() == 64 else {
    raise fail(
      "计算 SHA256 失败：无法读取文件 \{file_path} | hash: \{Repr(hash)}",
    )
  }
  hash
}

///|
/// 验证下载文件的 SHA256 是否与期望值匹配
pub fn verify_file_checksum(
  file_path : String,
  expected_sha256 : String,
) -> Bool {
  let actual_sha256 = compute_file_sha256(file_path) catch {
    e => {
      @log.warn("无法计算文件 SHA256：\{e}")
      return false
    }
  }
  @log.debug(
    "SHA256 校验：期望=\{expected_sha256.to_lower()} 实际=\{actual_sha256}",
  )
  actual_sha256 == expected_sha256.to_lower()
}
