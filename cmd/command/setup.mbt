///|
/// 执行 setup 命令：创建工具 wrapper 脚本，配置 PATH
/// use_prefix=true 使用固定前缀 TOOL_PREFIX，use_prefix=false 不使用前缀（默认）
async fn run_setup(use_prefix : Bool) -> CommandResult {
  let result = CommandResult::success()
  let prefix_str = if use_prefix { TOOL_PREFIX } else { "" }
  let os = @os.get_os_name()
  let bin_dir = @tool_def.mvm_bin_home()
  let npm_dir = @tool_def.mvm_npm_pkg_home()
  let tools = Tool::all_tools()
  let delete_names = []
  let add_names = []
  for tool in tools {
    delete_names.push(tool.to_string())
    let executable_names = tool.get_executable_programs()
    delete_names.append(executable_names)
    add_names.append(executable_names)
  }

  // 确保 bin 目录和 npm-pkg 目录存在
  @fs_ext.ensure_dir(bin_dir)
  @fs_ext.ensure_dir(npm_dir)

  // 清理旧的工具
  cleanup_old_shims(bin_dir, delete_names)
  // 创建新的工具
  create_new_shims(add_names, prefix_str)

  match os {
    MacOS | Linux => setup_unix(bin_dir, npm_dir, tools, prefix_str, result)
    Windows => setup_windows(bin_dir, npm_dir, tools, prefix_str, result)
    _ => raise fail("不支持的操作系统：\{os}")
  }
  result
}

///|
async fn remove_names(
  bin_dir : String,
  delete_names : Array[String],
  exts? : Array[String] = [""],
) -> Unit {
  for name in delete_names {
    for prefix in ["", TOOL_PREFIX] {
      for ext in exts {
        let prefixed = @fs_ext.join_path(bin_dir, prefix + name + ext)
        let _ = @fs_ext.remove_if_exists(prefixed) catch {
          e => @log.warn("无法删除 \{prefixed} \{e}")
        }
      }
    }
  }
}

///|
async fn cleanup_old_shims(
  bin_dir : String,
  delete_names : Array[String],
) -> Unit {
  // 清除旧版本的 executor 脚本（已更名为 debug）
  for ext in [".sh", ".ps1", ".cmd", ""] {
    let executor_path = @fs_ext.join_path(bin_dir, "executor\{ext}")
    @fs_ext.remove_if_exists(executor_path)
  }
  remove_names(bin_dir, delete_names, exts=["", ".ps1", ".cmd"])
}

///|
async fn create_new_shims(
  add_names : Array[String],
  prefix_str : String,
) -> Unit {
  let os = @os.get_os_name()
  for name in add_names {
    let belonging_tool = @tools.Tool::get_belonging_tool(name)
    let cmd_name = name
    match os {
      MacOS | Linux =>
        @tools.create_tool_cmd_unix(
          belonging_tool,
          cmd_name,
          file_name=prefix_str + cmd_name,
        )
      Windows =>
        @tools.create_tool_cmd_windows(
          belonging_tool,
          cmd_name,
          file_name=prefix_str + cmd_name,
        )
      _ => ()
    }
  }
}

///|
async fn setup_unix(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
  result : CommandResult,
) -> Unit {
  // 配置 PATH
  configure_path_unix(bin_dir, npm_dir)

  // 打印成功消息
  print_success_unix(bin_dir, npm_dir, tools, prefix_str, result)
}

///|
fn detect_shell_profile() -> String {
  let shell = @env.get_env_var("SHELL").unwrap_or("")
  let home = @env.get_env_var("HOME").unwrap_or("")
  if shell.contains("zsh") {
    @fs_ext.join_path(home, ".zshrc")
  } else if shell.contains("bash") {
    match @os.get_os_name() {
      MacOS => @fs_ext.join_path(home, ".bash_profile")
      _ => @fs_ext.join_path(home, ".bashrc")
    }
  } else {
    @fs_ext.join_path(home, ".profile")
  }
}

///|
async fn configure_path_unix(bin_dir : String, npm_dir : String) -> Unit {
  let profile_path = detect_shell_profile()
  if !@fs.exists(profile_path) {
    @fs.write_file(profile_path, "", create_mode=CreateOrTruncate)
  }
  let content = @fs.read_file(profile_path).text()

  let entries = [bin_dir, npm_dir]
  let mut new_lines = ""
  for entry in entries {
    // 检查是否已存在 PATH 配置（两种模式：开头或中间）
    let pattern1 = "export PATH=\"\{entry}:"
    let pattern2 = ":\{entry}:"
    if !content.contains(pattern1) && !content.contains(pattern2) {
      new_lines += "\nexport PATH=\"\{entry}:$PATH\""
    }
  }

  if new_lines != "" {
    let new_content = content + new_lines + "\n"
    @fs.write_file(profile_path, new_content, create_mode=CreateOrTruncate)
    // @log 日志不捕获到 CommandResult
    @log.info("已将 PATH 配置写入 \{profile_path}")
  } else {
    // @log 日志不捕获到 CommandResult
    @log.info("PATH 已配置，无需修改 \{profile_path}")
  }
}

///|
fn print_success_unix(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
  result : CommandResult,
) -> Unit {
  let display_names = tools.map(tool => prefix_str + tool.to_string())
  let tools_str = display_names.join(" ")
  let profile_path = detect_shell_profile()
  print_to(result, "")
  print_to(result, "安装完成！可执行文件已安装到 \{bin_dir}")
  print_to(result, "  - mvm         (主命令)")
  print_to(
    result,
    "  - npm-pkg 目录    (npm 全局包安装路径：\{npm_dir})",
  )
  print_to(result, "  工具软连接：\{tools_str}")
  print_to(result, "")
  print_to(
    result,
    @utils.yellow("如果 mvm 命令无效，请重启终端或执行："),
  )
  print_to(result, @utils.yellow("   source \{profile_path}"))
}

///|
async fn setup_windows(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
  result : CommandResult,
) -> Unit {
  // 配置 PATH
  configure_path_windows(bin_dir, npm_dir)

  // 打印成功消息
  print_success_windows(bin_dir, npm_dir, tools, prefix_str, result)
}

///|
async fn configure_path_windows(bin_dir : String, npm_dir : String) -> Unit {
  // 写临时 PowerShell 脚本来配置 PATH
  let temp_script = @fs_ext.join_path(bin_dir, "_setup_path.ps1")
  let entries = [bin_dir, npm_dir]
  let mut script = "$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')\n$modified = $false\n"
  for path_entry in entries {
    script += "$mvmEntry = '\{path_entry}'\n"
    script += "$escapedEntry = [regex]::Escape($mvmEntry)\n"
    script += "if ($currentPath -notmatch $escapedEntry) {\n"
    script += "    $currentPath = \"$mvmEntry;$currentPath\"\n"
    script += "    $modified = $true\n"
    script += "}\n"
  }
  script += "if ($modified) {\n"
  script += "    [Environment]::SetEnvironmentVariable('PATH', $currentPath, 'User')\n"
  script += "}\n"

  @fs.write_file(temp_script, script, create_mode=CreateOrTruncate)
  let _ = @process.run("powershell", [
    "-ExecutionPolicy", "Bypass", "-File", temp_script,
  ])
  // 清理临时文件
  let _ = @fs.remove(temp_script) catch { _ => () }
  // @log 日志不捕获到 CommandResult
  @log.info("已将 PATH 配置写入 Windows 用户环境变量")
}

///|
fn print_success_windows(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
  result : CommandResult,
) -> Unit {
  let display_names = tools.map(tool => prefix_str + tool.to_string())
  let tools_str = display_names.join(", ")
  print_to(result, "")
  print_to(result, "安装完成！可执行文件已安装到 \{bin_dir}")
  print_to(result, "  - mvm.exe         (主命令)")
  print_to(
    result,
    "  - npm-pkg 目录    (npm 全局包安装路径：\{npm_dir})",
  )
  print_to(result, "  工具脚本：\{tools_str}")
  print_to(result, "  (.ps1 for PowerShell, .cmd for cmd.exe/npm postinstall)")
  print_to(result, "")
  print_to(
    result,
    @utils.yellow("如果 mvm 命令无效，请重启终端或执行："),
  )
  let path_hint = "$env:PATH = [Environment]::GetEnvironmentVariable(\"PATH\",\"User\") + \";\" + $env:PATH"
  print_to(result, @utils.yellow("   \{path_hint}"))
}
