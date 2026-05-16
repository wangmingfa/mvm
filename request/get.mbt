///|
/// 顺序尝试 URL 列表获取内容，首个成功即返回
/// 用于代理优先 + 原链接兜底的场景（某些代理未实现辅助文件代理）
/// 返回 Some((成功的URL, 文件内容)) 或 None（所有URL均失败）
pub async fn try_urls(
  urls : Array[String],
  headers? : Map[String, String] = {},
  desc : String,
) -> (String, String)? {
  let headers = merge_detault_headers(headers~)
  for url in urls {
    let (res, data) = @http.get(url, headers~)
    if res.code is (200..<300) {
      return Some((url, data.text()))
    }
    @log.warn(
      "无法从 \{@utils.blue(url)} 获取 \{desc}: \{res.code} \{res.reason}",
    )
  }
  None
}
