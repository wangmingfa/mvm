async fn main {
  // 执行示例：/path/to/bun.exe run dev
  let args = @env.args()
  // 从第一个参数获取文件名称，并从中截取工具名
  let file_name = @fs_ext.get_path_name(args[0])
  let tool_name = file_name.split(".exe").to_array()[0].to_owned()
  // 剩余参数
  let rest_args = args[1:]
  let args = ["run", tool_name, tool_name, ..rest_args]
  // 最终运行：mvm run bun bun run dev
  let exit = @process.run("mvm", args)
  @sys.exit(exit)
}