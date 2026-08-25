async fn main {
  // 执行示例：
  //   unix: /path/to/bun run dev
  //   windows: D:\\path\\to\\bun.exe run dev
  let args = @env.args()
  // 从第一个参数（exe 自身路径）取文件名，例如 npm.exe -> npm
  let file_name = @fs_ext.get_path_name(args[0])
  let program_name = file_name.split(".exe").to_array()[0].to_owned()
  // 程序名不等于工具名：npm/npx/corepack 属于 node，bunx 属于 bun 等。
  // 必须把「程序名」推导成「所属工具名」后再转发，否则 mvm run npm ...
  let tool = @tools.Tool::get_belonging_tool(program_name)
  let tool_name = tool.to_str()
  // 剩余参数（用户传入的原始参数，不含 exe 自身）
  let rest_args = args[1:]
  // 最终运行：mvm run <tool> <program> <args...>
  //   npm.exe  -> mvm run node npm view ...
  //   bun.exe   -> mvm run bun  bun  run dev
  let run_args = ["run", tool_name, program_name, ..rest_args]
  let exit = @process.run("mvm", run_args)
  @sys.exit(exit)
}
