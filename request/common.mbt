///|
pub fn merge_detault_headers(
  headers? : Map[String, String] = {},
) -> Map[String, String] {
  // 注意：不包含 Accept-Encoding 头
  // MoonBit 的 @http.get 不自动解压 gzip/br 响应，如果发送 Accept-Encoding
  // 服务器可能返回压缩数据，导致 data.text() 解码时抛出 utf8.Malformed 错误
  // 实际的大文件下载通过 curl/PowerShell 处理，它们有自己的压缩机制
  let merged_headers = {
    "User-Agent": "curl/8.7.1",
    "Accept": "*/*",
    "Connection": "keep-alive",
  }
  for k, v in headers {
    merged_headers.set(k, v)
  }
  merged_headers
}
