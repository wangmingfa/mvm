///|
/// 执行 setup 命令：创建工具 wrapper 脚本，配置 PATH
/// use_prefix=true 使用固定前缀 TOOL_PREFIX，use_prefix=false 不使用前缀（默认）
pub async fn run_setup(use_prefix : Bool) -> Unit {
  let prefix_str = if use_prefix { TOOL_PREFIX } else { "" }
  let os = @os.get_os_name()
  let bin_dir = @tool_def.mvm_bin_home()
  let npm_dir = @tool_def.mvm_npm_pkg_home()
  let tools = Tool::all_tools()

  // 确保 bin 目录和 npm-pkg 目录存在
  @fs_ext.ensure_dir(bin_dir)
  @fs_ext.ensure_dir(npm_dir)

  match os {
    MacOS | Linux => setup_unix(bin_dir, npm_dir, tools, prefix_str)
    Windows => setup_windows(bin_dir, npm_dir, tools, prefix_str)
    _ => @log.error("不支持的操作系统：\{os}")
  }
}

///|
async fn setup_unix(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  // 清理旧的软连接
  cleanup_old_symlinks(bin_dir, tools)

  // 创建新的软连接
  create_symlinks(bin_dir, tools, prefix_str)

  // 配置 PATH
  configure_path_unix(bin_dir, npm_dir)

  // 打印成功消息
  print_success_unix(bin_dir, npm_dir, tools, prefix_str)
}

///|
async fn remove_tools(
  bin_dir : String,
  tools : Array[Tool],
  exts? : Array[String] = [""],
) -> Unit {
  for tool in tools {
    let tool_name = tool.to_string()
    for prefix in ["", TOOL_PREFIX] {
      for ext in exts {
        let prefixed = @fs_ext.join_path(bin_dir, prefix + tool_name + ext)
        let _ = @fs_ext.remove_if_exists(prefixed) catch {
          e => @log.warn("无法删除 \{prefixed} \{e}")
        }
      }
    }
  }
}

///|
async fn cleanup_old_symlinks(bin_dir : String, tools : Array[Tool]) -> Unit {
  remove_tools(bin_dir, tools)
}

///|
async fn create_symlinks(
  bin_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  let executor_path = @fs_ext.join_path(bin_dir, "executor.sh")
  if !@fs.exists(executor_path) {
    @log.warn("executor.sh 不存在，工具软连接可能无法正常工作")
  }

  for tool in tools {
    let display_name = prefix_str + tool.to_string()
    let wrapper_path = @fs_ext.join_path(bin_dir, display_name)
    let _ = @process.run("ln", ["-sf", executor_path, wrapper_path])
    @log.debug("创建软连接：\{wrapper_path} -> \{executor_path}")
  }
  // 添加可执行权限
  let wrapper_paths = tools.map(tool => {
    @fs_ext.join_path(bin_dir, prefix_str + tool.to_string())
  })
  @mvm_cmd.chmod_x([executor_path, ..wrapper_paths])
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
    @log.info("已将 PATH 配置写入 \{profile_path}")
  } else {
    @log.info("PATH 已配置，无需修改 \{profile_path}")
  }
}

///|
fn print_success_unix(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  let display_names = tools.map(tool => prefix_str + tool.to_string())
  let tools_str = display_names.join(" ")
  let profile_path = detect_shell_profile()
  println("")
  println("安装完成！可执行文件已安装到 \{bin_dir}")
  println("  - mvm         (主命令)")
  println("  - executor.sh (工具执行脚本)")
  println("  - npm-pkg 目录    (npm 全局包安装路径：\{npm_dir})")
  println("  工具软连接：\{tools_str}")
  println("")
  println("如果 mvm 命令无效，请重启终端或执行：")
  println("   source \{profile_path}")
}

///|
async fn setup_windows(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  // 清理旧的 shim 文件
  cleanup_old_shims(bin_dir, tools)

  // 创建新的 shim 文件
  create_shims(bin_dir, tools, prefix_str)

  // 配置 PATH
  configure_path_windows(bin_dir, npm_dir)

  // 打印成功消息
  print_success_windows(bin_dir, npm_dir, tools, prefix_str)
}

///|
async fn cleanup_old_shims(bin_dir : String, tools : Array[Tool]) -> Unit {
  remove_tools(bin_dir, tools, exts=["", ".ps1", ".cmd"])
}

///|
async fn create_shims(
  bin_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  let executor_path = @fs_ext.join_path(bin_dir, "executor.ps1")
  let mvm_exe_path = @fs_ext.join_path(bin_dir, "mvm.exe")

  for tool in tools {
    let display_name = prefix_str + tool.to_string()

    // 创建 .ps1 shim — PowerShell 直接调用
    let ps1_path = @fs_ext.join_path(bin_dir, display_name + ".ps1")
    let ps1_content = "#!/usr/bin/env pwsh\n& \"\{executor_path}\" \{display_name} $args"
    @fs.write_file(ps1_path, ps1_content, create_mode=CreateOrTruncate)

    // 创建 .cmd shim — cmd.exe 调用（npm postinstall 等场景）
    let cmd_path = @fs_ext.join_path(bin_dir, display_name + ".cmd")
    let cmd_content = "@echo off\r\n\"\{mvm_exe_path}\" executor \{display_name} %*"
    @fs.write_file(cmd_path, cmd_content, create_mode=CreateOrTruncate)

    @log.debug("创建 shim 文件：\{ps1_path}, \{cmd_path}")
  }
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
  @log.info("已将 PATH 配置写入 Windows 用户环境变量")
}

///|
fn print_success_windows(
  bin_dir : String,
  npm_dir : String,
  tools : Array[Tool],
  prefix_str : String,
) -> Unit {
  let display_names = tools.map(tool => prefix_str + tool.to_string())
  let tools_str = display_names.join(", ")
  println("")
  println("安装完成！可执行文件已安装到 \{bin_dir}")
  println("  - mvm.exe         (主命令)")
  println("  - executor.ps1    (工具执行脚本)")
  println("  - npm-pkg 目录    (npm 全局包安装路径：\{npm_dir})")
  println("  工具脚本：\{tools_str}")
  println("  (.ps1 for PowerShell, .cmd for cmd.exe/npm postinstall)")
  println("")
  println("如果 mvm 命令无效，请重启终端或执行：")
  let path_hint = "$env:PATH = [Environment]::GetEnvironmentVariable(\"PATH\",\"User\") + \";\" + $env:PATH"
  println("   \{path_hint}")
}
