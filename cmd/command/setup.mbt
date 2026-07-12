///|
/// 交互式选择工具（使用 promptx checkbox 实现）
/// 返回用户选择的工具列表
async fn interactive_select_tools() -> Array[Tool] {
  let all_tools = Tool::all_tools()
  let tool_names = all_tools.map(tool => tool.to_string())
  let (_, global_config) = @tools.get_global_config()
  let preselected = match global_config.managed_tools {
    Some(str) if !str.is_blank() =>
      str.split(",").map(s => s.trim().to_owned()).to_array()
    _ => []
  }
  let title = @i18n.t("setup.select_tools_title")
  let selected_json = @promptx.checkbox(title, tool_names, default_items=preselected)
  let json_val = @json.parse(selected_json) catch {
    _ => raise fail(@i18n.t("error.cannot_be_empty"))
  }
  guard json_val is Array(selected_names) else {
    raise fail(@i18n.t("error.cannot_be_empty"))
  }
  if selected_names.length() == 0 {
    raise fail(@i18n.t("error.cannot_be_empty"))
  }
  let result : Array[Tool] = []
  for name in selected_names {
    guard name is String(trimmed_name) else { continue }
    let trimmed = trimmed_name.trim().to_owned()
    if trimmed != "" {
      let tool = Tool::from_string_with_option_result(trimmed)
      match tool {
        Some(t) => result.push(t)
        None => ()
      }
    }
  }
  if result.length() == 0 {
    raise fail(@i18n.t("error.cannot_be_empty"))
  }
  let tool_names_str = result.map(tool => tool.to_string()).join(", ")
  println(@i18n.t("setup.selected_tools", args={ "tools": tool_names_str }))
  result
}

///|
/// 执行 setup 命令：创建工具 wrapper 脚本，配置 PATH
/// use_prefix=true 使用固定前缀 TOOL_PREFIX，use_prefix=false 不使用前缀（默认）
/// tools=None 表示交互选择工具，tools=Some("all") 表示管理所有工具，tools=Some("node,bun") 表示管理指定工具
async fn run_setup(use_prefix : Bool, tools : String?) -> CommandResult {
  let result = CommandResult::success()
  let prefix_str = if use_prefix { TOOL_PREFIX } else { "" }
  let os = @os.get_os_name()
  let bin_dir = @tool_def.mvm_bin_home()
  let npm_dir = @tool_def.mvm_npm_pkg_home()
  // 根据 tools 参数决定管理哪些工具
  let managed_tools = match tools {
    None =>
      // 交互选择工具
      interactive_select_tools()
    Some("all") => Tool::all_tools()
    Some(value) =>
      if value.is_blank() {
        []
      } else {
        value
        .split(",")
        .filter(v => !v.is_blank())
        .map(v => {
          let trimmed = v.trim().to_owned()
          match Tool::from_string_with_option_result(trimmed) {
            Some(tool) => Some(tool)
            None => {
              @log.warn(
                "setup --tools 中包含不支持的工具名：\{trimmed}",
              )
              None
            }
          }
        })
        .filter(v => v is Some(_))
        .map(v => v.unwrap())
        .to_array()
      }
  }
  // 保存 managed_tools 到 GlobalConfig
  let managed_tools_str = managed_tools.map(t => t.to_string()).join(",")
  let (_, existing_config) = @tools.get_global_config()
  let new_config = @tools.make_global_config(
    existing_config~,
    managed_tools=Some(managed_tools_str),
  )
  let _ = @tools.save_global_config(new_config)
  let delete_names = []
  let add_names = managed_tools
    .map(v => v.get_executable_programs().iter().to_array())
    .flatten()
  for tool in Tool::all_tools() {
    delete_names.push(tool.to_string())
    let executable_names = tool.get_executable_programs()
    delete_names.append(executable_names)
  }

  // 确保 bin 目录和 npm-pkg 目录存在
  @fs_ext.ensure_dir(bin_dir)
  @fs_ext.ensure_dir(npm_dir)

  // 清理旧的工具
  cleanup_old_shims(bin_dir, delete_names)
  // 创建新的工具
  create_new_shims(add_names, prefix_str)

  match os {
    MacOS | Linux =>
      setup_unix(bin_dir, npm_dir, managed_tools, prefix_str, result)
    Windows =>
      setup_windows(bin_dir, npm_dir, managed_tools, prefix_str, result)
    // 不支持的操作系统
    _ =>
      raise fail(@i18n.t("setup.unsupported_os", args={ "os": os.to_string() }))
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
          // 无法删除文件
          e =>
            @log.warn(
              @i18n.t("setup.cannot_delete", args={
                "path": prefixed,
                "error": e.to_string(),
              }),
            )
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
    // 已将 PATH 配置写入
    @log.info(@i18n.t("setup.path_configured", args={ "path": profile_path }))
  } else {
    // PATH 已配置，无需修改
    @log.info(
      @i18n.t("setup.path_already_configured", args={ "path": profile_path }),
    )
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
  // 安装完成
  print_to(result, @i18n.t("setup.install_complete", args={ "dir": bin_dir }))
  // 主命令
  print_to(result, "  - mvm         (\{@i18n.t("setup.main_command")})")
  // npm 全局包安装路径
  print_to(result, @i18n.t("setup.npm_pkg_dir", args={ "dir": npm_dir }))
  // 工具软连接
  print_to(
    result,
    "  \{@i18n.t("setup.tool_symlinks", args={ "tools": tools_str })}",
  )
  print_to(result, "")
  // 如果 mvm 命令无效，请重启终端或执行
  print_to(result, @utils.yellow(@i18n.t("setup.restart_hint")))
  // source 命令
  print_to(
    result,
    @utils.yellow(
      "   \{@i18n.t("setup.source_command", args={ "path": profile_path })}",
    ),
  )
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
  // 已将 PATH 配置写入 Windows 用户环境变量
  @log.info(@i18n.t("setup.path_configured_windows"))
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
  // 安装完成
  print_to(result, @i18n.t("setup.install_complete", args={ "dir": bin_dir }))
  // 主命令
  print_to(result, "  - mvm.exe         (\{@i18n.t("setup.main_command")})")
  // npm 全局包安装路径
  print_to(result, @i18n.t("setup.npm_pkg_dir", args={ "dir": npm_dir }))
  // 工具脚本
  print_to(
    result,
    "  \{@i18n.t("setup.tool_scripts", args={ "tools": tools_str })}",
  )
  // Windows 脚本说明
  print_to(result, "  \{@i18n.t("setup.windows_script_note")}")
  print_to(result, "")
  // 如果 mvm 命令无效，请重启终端或执行
  print_to(result, @utils.yellow(@i18n.t("setup.restart_hint")))
  // Windows PATH 提示
  print_to(result, @utils.yellow("   \{@i18n.t("setup.windows_path_hint")}"))
}
