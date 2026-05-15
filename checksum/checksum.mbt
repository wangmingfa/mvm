///|
/// 计算文件的 SHA256 值
/// macOS 使用 shasum，Linux 使用 sha256sum，Windows 使用 PowerShell Get-FileHash
pub async fn compute_file_sha256(file_path : String) -> String raise {
  let os = @os.get_os_name()
  match os {
    MacOS => {
      // macOS: shasum -a 256 <file>
      let (code, output) = @process.collect_output_merged(
        "shasum",
        ["-a", "256", file_path],
      ) catch {
        _ => raise fail("无法执行 shasum 命令，请确保 macOS 系统工具可用")
      }
      guard code == 0 else {
        raise fail(
          "计算 SHA256 失败，shasum 返回退出码 \{code}：\{output.text()}",
        )
      }
      parse_sha256_output(output.text(), "  ")
    }
    Linux => {
      // Linux: sha256sum <file>
      let (code, output) = @process.collect_output_merged(
        "sha256sum",
        [file_path],
      ) catch {
        _ => raise fail("无法执行 sha256sum 命令，请安装 coreutils")
      }
      guard code == 0 else {
        raise fail(
          "计算 SHA256 失败，sha256sum 返回退出码 \{code}：\{output.text()}",
        )
      }
      parse_sha256_output(output.text(), "  ")
    }
    Windows => {
      // Windows: PowerShell Get-FileHash
      let ps_script =
        "(Get-FileHash -Algorithm SHA256 '\{file_path}').Hash"
      let (code, output) = @process.collect_output_merged(
        "powershell",
        ["-Command", ps_script],
      ) catch {
        _ =>
          raise fail(
            "无法执行 PowerShell Get-FileHash 命令",
          )
      }
      guard code == 0 else {
        raise fail(
          "计算 SHA256 失败，PowerShell 返回退出码 \{code}：\{output.text()}",
        )
      }
      // PowerShell 直接输出纯哈希值，无需额外解析
      output.text().trim().to_owned().to_lower()
    }
    _ => raise fail("不支持的操作系统：\{os}")
  }
}

///|
/// 从 shasum/sha256sum 输出中提取纯哈希值
/// 输出格式：<hash>  <filename> 或 <hash> <filename>
fn parse_sha256_output(output : String, separator : String) -> String {
  let trimmed = output.trim().to_owned()
  let parts = trimmed.split(separator).to_array()
  if parts.length() >= 1 {
    parts[0].trim().to_owned().to_lower()
  } else {
    trimmed.to_lower()
  }
}

///|
/// 验证下载文件的 SHA256 是否与期望值匹配
pub async fn verify_file_checksum(
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