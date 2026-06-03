///|
/// URL 替换上下文
pub struct UrlReplaceContext {
  url : String
  tool : String
  version : String
  os : String
  arch : String
}

///|
pub fn UrlReplaceContext::new(
  url : String,
  tool : String,
  version : String,
  os : String,
  arch : String,
) -> UrlReplaceContext {
  { url, tool, version, os, arch }
}

///|
/// 替换 URL 中的变量
/// 支持的变量：$URL, $TOOL, $VERSION, $OS, $ARCH
pub fn replace_url(template : String, ctx : UrlReplaceContext) -> String {
  let result = template
  result
  .replace(old="$URL", new=ctx.url)
  .replace(old="$TOOL", new=ctx.tool)
  .replace(old="$VERSION", new=ctx.version)
  .replace(old="$OS", new=ctx.os)
  .replace(old="$ARCH", new=ctx.arch)
}

///|
/// 应用全局配置转换 URL
/// node_mirror: 用于 Node.js 镜像（优先级高于 github_proxy）
/// github_proxy: 用于 GitHub 相关下载（如 node index.json）
pub fn apply_global_config(
  url : String,
  config : GlobalConfig,
  ctx : UrlReplaceContext,
) -> String {
  match config.node_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "node" => {
      @log.debug(@i18n.t("url.debug_node_mirror", args={ "mirror": mirror }))
      return url.replace(old=NODE_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.go_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "go" => {
      @log.debug(@i18n.t("url.debug_go_mirror", args={ "mirror": mirror }))
      return url.replace(old=GO_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.python_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "python" => {
      @log.debug(@i18n.t("url.debug_python_mirror", args={ "mirror": mirror }))
      return url.replace(old=PYTHON_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.rust_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "rust" => {
      @log.debug(@i18n.t("url.debug_rust_mirror", args={ "mirror": mirror }))
      return url.replace(old=RUST_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  match config.java_mirror {
    Some(mirror) if mirror != "" && ctx.tool == "java" => {
      @log.debug(@i18n.t("url.debug_java_mirror", args={ "mirror": mirror }))
      return url.replace(old=JAVA_RELEASE_URL, new=mirror)
    }
    _ => ()
  }
  // Deno 和 Kotlin 使用 github_proxy，无专属镜像
  match config.github_proxy {
    Some(proxy) if proxy != "" && url.has_prefix("https://github.com/") => {
      @log.debug(@i18n.t("url.debug_github_proxy", args={ "proxy": proxy }))
      return replace_url(proxy, ctx)
    }
    _ => ()
  }
  url
}

///|
test "replace_url 变量替换" {
  let ctx = UrlReplaceContext::new(
    "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip",
    "bun", "bun-v1.3.12", "darwin", "arm64",
  )
  // $URL 替换
  let result = replace_url("https://proxy.org/$URL", ctx)
  guard result ==
    "https://proxy.org/https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip" else {
    fail("URL replacement failed: \{result}")
  }
  // $TOOL 替换
  let result2 = replace_url("https://mirror.org/$TOOL/$VERSION", ctx)
  guard result2 == "https://mirror.org/bun/bun-v1.3.12" else {
    fail("TOOL replacement failed: \{result2}")
  }
  // $OS 和 $ARCH 替换
  let result3 = replace_url("https://mirror.org/$TOOL/$VERSION/$OS-$ARCH", ctx)
  guard result3 == "https://mirror.org/bun/bun-v1.3.12/darwin-arm64" else {
    fail("OS/ARCH replacement failed: \{result3}")
  }
}

///|
test "apply_global_config node_mirror" {
  // node_mirror 分支：tool 为 node 时，替换 NODE_RELEASE_URL
  let ctx = UrlReplaceContext::new(
    "https://nodejs.org/dist/v20.18.0/node-v20.18.0-darwin-arm64.tar.gz", "node",
    "v20.18.0", "darwin", "arm64",
  )
  let config = {
    github_proxy: None,
    node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://mirrors.aliyun.com/nodejs-release/v20.18.0/node-v20.18.0-darwin-arm64.tar.gz" else {
    fail("node_mirror replacement failed: \{result}")
  }
}

///|
test "apply_global_config go_mirror" {
  // go_mirror 分支：tool 为 go 时，替换 GO_RELEASE_URL
  let ctx = UrlReplaceContext::new(
    "https://go.dev/dl/go1.23.4.darwin-arm64.tar.gz", "go", "1.23.4", "darwin", "arm64",
  )
  let config = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: Some("https://mirrors.aliyun.com/golang"),
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://mirrors.aliyun.com/golang/go1.23.4.darwin-arm64.tar.gz" else {
    fail("go_mirror replacement failed: \{result}")
  }
}

///|
test "apply_global_config github_proxy" {
  // github_proxy 分支：URL 以 https://github.com/ 开头时，使用代理替换
  let ctx = UrlReplaceContext::new(
    "https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip",
    "bun", "bun-v1.3.12", "darwin", "arm64",
  )
  let config = {
    github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://cdn.gh-proxy.org/https://github.com/oven-sh/bun/releases/download/bun-v1.3.12/bun-darwin-aarch64.zip" else {
    fail("github_proxy replacement failed: \{result}")
  }
}

///|
test "apply_global_config no_config" {
  // 无配置时，原 URL 不变
  let ctx = UrlReplaceContext::new(
    "https://github.com/oven-sh/bun/releases/download/bun-v1.zip", "bun", "bun-v1",
    "darwin", "arm64",
  )
  let config = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result == ctx.url else {
    fail("no config should return original URL: \{result}")
  }
}

///|
test "apply_global_config node_mirror_priority" {
  // node_mirror 优先级高于 github_proxy（即使两者都设置了）
  let ctx = UrlReplaceContext::new(
    "https://nodejs.org/dist/v20.18.0/node-v20.18.0-darwin-arm64.tar.gz", "node",
    "v20.18.0", "darwin", "arm64",
  )
  let config = {
    github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
    node_mirror: Some("https://mirrors.aliyun.com/nodejs-release"),
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://mirrors.aliyun.com/nodejs-release/v20.18.0/node-v20.18.0-darwin-arm64.tar.gz" else {
    fail("node_mirror should have priority over github_proxy: \{result}")
  }
}

///|
test "apply_global_config python_mirror" {
  // python_mirror 分支：tool 为 python 时，替换 PYTHON_RELEASE_URL
  let ctx = UrlReplaceContext::new(
    "https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz", "python", "3.12.0",
    "linux", "x64",
  )
  let config = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: Some("https://mirrors.aliyun.com/python"),
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result == "https://mirrors.aliyun.com/python/3.12.0/Python-3.12.0.tgz" else {
    fail("python_mirror replacement failed: \{result}")
  }
}

///|
test "apply_global_config rust_mirror" {
  // rust_mirror 分支：tool 为 rust 时，替换 RUST_RELEASE_URL
  let ctx = UrlReplaceContext::new(
    "https://static.rust-lang.org/dist/rust-1.80.0-x86_64-apple-darwin.tar.gz", "rust",
    "1.80.0", "darwin", "arm64",
  )
  let config = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: Some("https://mirrors.aliyun.com/rustup"),
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://mirrors.aliyun.com/rustup/rust-1.80.0-x86_64-apple-darwin.tar.gz" else {
    fail("rust_mirror replacement failed: \{result}")
  }
}

///|
test "apply_global_config java_mirror" {
  // java_mirror 分支：tool 为 java 时，替换 JAVA_RELEASE_URL
  // Java 下载已改为 GitHub releases，java_mirror 仅影响 Adoptium API URL（如可用版本查询）
  let ctx = UrlReplaceContext::new(
    "https://api.adoptium.net/v3/info/available_releases", "java", "latest", "",
    "",
  )
  let config = {
    github_proxy: None,
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: Some("https://mirrors.aliyun.com/adoptium"),
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://mirrors.aliyun.com/adoptium/v3/info/available_releases" else {
    fail("java_mirror replacement failed: \{result}")
  }
}

///|
test "apply_global_config deno uses github_proxy" {
  // Deno 使用 github_proxy（无专属镜像）
  let ctx = UrlReplaceContext::new(
    "https://github.com/denoland/deno/releases/download/v1.40.0/deno-aarch64-apple-darwin.zip",
    "deno", "v1.40.0", "darwin", "arm64",
  )
  let config = {
    github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://cdn.gh-proxy.org/https://github.com/denoland/deno/releases/download/v1.40.0/deno-aarch64-apple-darwin.zip" else {
    fail("deno github_proxy replacement failed: \{result}")
  }
}

///|
test "apply_global_config kotlin uses github_proxy" {
  // Kotlin 使用 github_proxy（无专属镜像）
  let ctx = UrlReplaceContext::new(
    "https://github.com/JetBrains/kotlin/releases/download/v2.0.0/kotlin-compiler-2.0.0.zip",
    "kotlin", "v2.0.0", "darwin", "arm64",
  )
  let config = {
    github_proxy: Some("https://cdn.gh-proxy.org/$URL"),
    node_mirror: None,
    go_mirror: None,
    python_mirror: None,
    rust_mirror: None,
    java_mirror: None,
    language: None,
    managed_tools: None,
  }
  let result = apply_global_config(ctx.url, config, ctx)
  guard result ==
    "https://cdn.gh-proxy.org/https://github.com/JetBrains/kotlin/releases/download/v2.0.0/kotlin-compiler-2.0.0.zip" else {
    fail("kotlin github_proxy replacement failed: \{result}")
  }
}
