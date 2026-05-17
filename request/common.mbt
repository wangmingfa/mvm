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

///|
/// 构建 GitHub API 请求所需的 headers
/// 包含默认 headers + GitHub API 专用 Accept 头 + 可选的 Authorization（GITHUB_TOKEN/GH_TOKEN）
/// GitHub API 对没有 User-Agent 的请求返回 403 Forbidden
/// 设置 GITHUB_TOKEN 环境变量可提升速率限制（60 → 5000 次/小时）
pub fn github_headers(
  headers? : Map[String, String] = {},
) -> Map[String, String] {
  let merged = merge_detault_headers()
  // GitHub API 推荐 Accept 头，确保返回 JSON 格式
  merged.set("Accept", "application/vnd.github+json")
  // 读取 GitHub Token 环境变量（优先 GITHUB_TOKEN，其次 GH_TOKEN）
  let token = @env.get_env_var("GITHUB_TOKEN").unwrap_or(
    @env.get_env_var("GH_TOKEN").unwrap_or(""),
  )
  if !token.is_blank() {
    merged.set("Authorization", "Bearer \{token}")
    // GitHub API 新版认证需要 X-GitHub-Api-Version 头
    merged.set("X-GitHub-Api-Version", "2022-11-28")
  }
  for k, v in headers {
    merged.set(k, v)
  }
  merged
}

///|
/// 便捷方法：对 GitHub API URL 发送 GET 请求
/// 自动附带 GitHub API 专用 headers（含 User-Agent、Accept、可选 Authorization）
pub async fn github_get(
  url : String,
  headers? : Map[String, String] = {},
) -> (@http.Response, &@io.Data) {
  @http.get(url, headers=github_headers(headers~))
}
