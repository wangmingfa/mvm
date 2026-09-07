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
    "file:../some-pkg",
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
