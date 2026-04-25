///|
async fn main {
  let args = @env.args()
  guard args.get(1) is Some(exe_name) else {
    println("命令不合法")
    return
  }
  let exe_name = @fs_ext.get_path_name(exe_name)
  guard exe_name.split(".").next() is Some(tool_name)
  let tool = @tools.Tool::from_string(tool_name.to_string())
  let exe_args = args[2:]
  let args_str = exe_args.join(" ")
  let tool_exe_path = @tools.get_tool_exe_path(tool)

  // TODO 有可能没有安装
  if tool_exe_path.is_blank() {
    println(@utils.red("请先安装\{exe_name}"))
    return
  }

  let cmd = "\{tool_exe_path} \{args_str}"
  println("运行：\{cmd}")
  let _ = @process.run(tool_exe_path, exe_args)
}
