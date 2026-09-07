///|
test "extract_pkgs_from_args strips version and alias spec" {
  let cmds : ReadOnlyArray[String] = ["install", "i"]
  // 模拟：npm install -g xxx@beta yyy@1.2.3 @scope/name@latest my-cli@npm:some-cli@2.0.0 @my/alias@npm:@scope/real
  let args : Array[String] = [
    "install", "-g", "xxx@beta", "yyy@1.2.3", "@scope/name@latest", "my-cli@npm:some-cli@2.0.0",
    "@my/alias@npm:@scope/real",
  ]
  let pkgs = extract_pkgs_from_args(args, cmds)
  assert_eq(pkgs, ["xxx", "yyy", "@scope/name", "my-cli", "@my/alias"])
  // 不带版本号的普通包不受影响
  let plain : Array[String] = ["i", "-g", "typescript", "@google/gemini-cli"]
  assert_eq(extract_pkgs_from_args(plain, cmds), [
    "typescript", "@google/gemini-cli",
  ])
}

///|
test "extract_pkgs_from_args skips non-package specs" {
  let cmds : ReadOnlyArray[String] = ["install", "i"]
  let uninstall : ReadOnlyArray[String] = ["uninstall", "un"]
  // 本地 tarball / 目录 / 远程 URL 不是包标识符，应被跳过（否则会拼成非法 node_modules 路径）
  let args : Array[String] = [
    "install", "-g",
    "D:\\code\\syncx\\wangmingfa-syncx-0.1.1.tgz",
    "./local-pkg",
    "../parent/pkg",
    "/abs/path/pkg",
    "https://registry.npmjs.org/x/-/x-1.0.0.tgz",
    "git+https://github.com/a/b.git",
    "git+ssh://git@github.com/a/b.git",
    "git://github.com/a/b.git",
    "file:../some-pkg",
    // 含冒号的 shorthand（非 @npm: 别名），应跳过
    "github:user/repo",
    "gitlab:user/repo",
    "bitbucket:user/repo",
    "gist:xxxx",
    "git@github.com:user/repo.git",
  ]
  assert_eq(extract_pkgs_from_args(args, cmds), [])
  // 卸载路径下同样跳过
  let unargs : Array[String] = [
    "uninstall", "-g", "D:\\code\\syncx\\wangmingfa-syncx-0.1.1.tgz",
  ]
  assert_eq(extract_pkgs_from_args(unargs, uninstall), [])
  // 真实包名仍可正常剥离版本号（与跳过逻辑不冲突）
  let mixed : Array[String] = [
    "install", "-g", "xxx@beta", "D:\\x.tgz", "@scope/name@latest",
  ]
  assert_eq(extract_pkgs_from_args(mixed, cmds), ["xxx", "@scope/name"])
}

///|
/// 覆盖 npm 完整的 package spec 文法（参考 npm docs: configuring-npm/package-spec）。
/// 确保每个安装 spec 形式都能被正确处理：registry 名/版本/范围/dist-tag、
/// scoped、@npm: 别名、tarball/目录/git URL 等。
test "extract_pkgs_from_args npm install spec grammar" {
  let ic : ReadOnlyArray[String] = ["install", "i"]
  // 1. 普通包名（latest）
  assert_eq(extract_pkgs_from_args(["i", "-g", "typescript"], ic), ["typescript"])
  // 2. 精确版本
  assert_eq(
    extract_pkgs_from_args(["install", "-g", "typescript@5.0.0"], ic),
    ["typescript"],
  )
  // 3. 版本范围（无空格）
  assert_eq(extract_pkgs_from_args(["i", "-g", "react@^18.2.0"], ic), ["react"])
  assert_eq(extract_pkgs_from_args(["i", "-g", "react@~18.2.0"], ic), ["react"])
  // 4. dist-tag
  assert_eq(extract_pkgs_from_args(["i", "-g", "vue@beta"], ic), ["vue"])
  assert_eq(extract_pkgs_from_args(["i", "-g", "vue@next"], ic), ["vue"])
  // 5. scoped 包（latest）
  assert_eq(extract_pkgs_from_args(["i", "-g", "@types/node"], ic), ["@types/node"])
  // 6. scoped + 版本
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "@types/node@20.0.0"], ic),
    ["@types/node"],
  )
  // 7. scoped + dist-tag
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "@scope/name@beta"], ic),
    ["@scope/name"],
  )
  // 8. @npm: 别名（latest）
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "my-cli@npm:some-cli"], ic),
    ["my-cli"],
  )
  // 9. @npm: 别名 + 版本
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "my-cli@npm:some-cli@2.0.0"], ic),
    ["my-cli"],
  )
  // 10. @npm: 别名指向 scoped 原包
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "@my/alias@npm:@scope/real"], ic),
    ["@my/alias"],
  )
  // 11. tarball URL（含 https）
  assert_eq(
    extract_pkgs_from_args(
      ["i", "-g", "https://registry.npmjs.org/foo/-/foo-1.0.0.tgz"],
      ic,
    ),
    [],
  )
  // 12. git URL（多种协议）
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "git+https://github.com/a/b.git"], ic),
    [],
  )
  assert_eq(
    extract_pkgs_from_args(["i", "-g", "git+ssh://git@github.com/a/b.git"], ic),
    [],
  )
  // 13. 含冒号的 shorthand（非 @npm: 别名）
  assert_eq(extract_pkgs_from_args(["i", "-g", "github:user/repo"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "gitlab:user/repo"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "gist:xxxx"], ic), [])
  // 14. 本地 tarball（相对 / 绝对 / Windows 盘符）
  assert_eq(extract_pkgs_from_args(["i", "-g", "./foo.tgz"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "../foo.tgz"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "/abs/foo.tgz"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "D:\\code\\x\\foo.tgz"], ic), [])
  // 15. 本地目录
  assert_eq(extract_pkgs_from_args(["i", "-g", "./mypkg"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "../mypkg"], ic), [])
  assert_eq(extract_pkgs_from_args(["i", "-g", "file:./mypkg"], ic), [])
  // 16. 混合：registry / 版本 / 别名 / tarball 同一条命令
  assert_eq(
    extract_pkgs_from_args(
      ["i", "-g", "a@beta", "b", "c@npm:d@1.0.0", "./local.tgz", "@scope/e@latest"],
      ic,
    ),
    ["a", "b", "c", "@scope/e"],
  )
  // 17. value flag 及其值被消费
  assert_eq(
    extract_pkgs_from_args(
      ["i", "-g", "--registry", "https://x.com", "pkg"],
      ic,
    ),
    ["pkg"],
  )
  assert_eq(
    extract_pkgs_from_args(
      ["install", "--global", "--prefix", "/tmp/x", "pkg@1.0.0"],
      ic,
    ),
    ["pkg"],
  )
  // 18. 非全局安装（无 -g）：仍按 spec 解析，路由层不会走 global 分支
  assert_eq(extract_pkgs_from_args(["i", "typescript@5.0.0"], ic), ["typescript"])
  // 19. 纯本地安装（无包名）
  assert_eq(extract_pkgs_from_args(["i"], ic), [])
}

///|
/// 覆盖 after_npm_command 的全局安装 / 卸载路由判定。
test "npm global install/uninstall routing" {
  // 全局安装判定：必须有 install 命令且带 -g / --global
  assert_true(is_global_install(["i", "-g", "x"]))
  assert_true(is_global_install(["install", "--global", "x"]))
  assert_true(is_global_install(["i", "-g", "--prefix", "/tmp", "x.tgz"]))
  assert_true(is_global_install(["install", "-g", "@types/node@beta"]))
  assert_true(is_global_install(["i", "-g"]))
  // 非全局：缺 -g / --global
  assert_true(!is_global_install(["i", "x"]))
  assert_true(!is_global_install(["install"]))
  // 卸载命令不应判为安装
  assert_true(!is_global_install(["uninstall", "-g", "x"]))
  // 全局卸载判定：必须有 uninstall 命令且带 -g / --global
  assert_true(is_global_uninstall(["uninstall", "-g", "x"]))
  assert_true(is_global_uninstall(["un", "--global", "x"]))
  assert_true(!is_global_uninstall(["uninstall", "x"]))
  assert_true(!is_global_uninstall(["i", "-g", "x"]))
}
