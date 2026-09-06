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
