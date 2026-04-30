///|
pub async fn handle_npm_command(args : ArrayView[String]) -> Unit {
  let install_cmds = ["install", "i"]

  let global_flgas = ["--global", "-g"]
  // 判断是否为npm的全局安装，如果是，获取args中所有安装的包名
  let is_global_install = args
    .iter()
    .any(arg => install_cmds.iter().any(fn(cmd) { arg == cmd })) &&
    args.iter().any(arg => global_flgas.iter().any(fn(flag) { arg == flag }))
  if is_global_install {
    let pkgs = args.filter(fn(arg) {
      !install_cmds.any(cmd => arg == cmd) &&
      !global_flgas.any(flag => arg == flag)
    })
    handle_install_npm_global_package(pkgs)
  } else {
    ...
  }
}

///|
async fn handle_install_npm_global_package(pkgs : ArrayView[String]) -> Unit {
  // 全局安装
  println("全局安装: \{pkgs}")
}
