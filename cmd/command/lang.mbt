///|
/// 执行 lang install 命令：将外部语言包 JSON 文件复制到 MVM_HOME/langs 并加载
async fn run_lang_install(path : String) -> CommandResult {
  let result = CommandResult::success()
  // 检查源文件是否存在
  if !@fs.exists(path) {
    // 文件不存在
    raise fail(@i18n.t("error.file_not_found", args={ "path": path }))
  }
  // 读取 JSON 文件内容并校验格式
  let content = @fs.read_file(path)
  let json = content.json() catch {
    // JSON格式无效
    _ => raise fail(@i18n.t("error.invalid_json", args={ "path": path }))
  }
  // 校验 JSON 为 Object 且包含翻译键值对
  guard json is Object(map) else {
    // JSON必须是键值对格式
    raise fail(@i18n.t("lang.json_must_be_kv"))
  }
  // 从文件名提取语言代码（去掉目录和扩展名）
  let filename = @fs_ext.get_path_name(path)
  let lang_code : String = if filename.has_suffix(".json") {
    filename[0:filename.length() - 5].to_owned() // 去掉 .json 后缀
  } else {
    filename.to_string()
  }
  // 内置语言不允许安装覆盖
  let lower = lang_code.to_lower()
  if lower == "zh" || lower == "zh-cn" || lower == "en" || lower == "en-us" {
    // 不能覆盖内置语言
    raise fail(
      @i18n.t("lang.cannot_override_builtin", args={ "lang": lang_code }),
    )
  }
  // 复制到 MVM_HOME/langs 目录
  let mvm_home = @tools.mvm_home()
  let langs_dir = @fs_ext.join_path(mvm_home, "langs")
  // 确保 langs 目录存在
  if !@fs.exists(langs_dir) {
    @fs.mkdir(langs_dir, recursive=true) catch {
      // 创建目录失败
      _ =>
        raise fail(
          @i18n.t("lang.create_dir_failed", args={ "path": langs_dir }),
        )
    }
  }
  let dest_path = @fs_ext.join_path(langs_dir, lang_code + ".json")
  @fs.write_file(dest_path, content, create_mode=CreateOrTruncate)
  // 加载外部字典
  @i18n.load_external_dict(lang_code)
  // 输出结果
  // 语言包已安装
  print_to(result, @i18n.t("lang.installed_label", args={ "code": lang_code }))
  // 源文件
  print_to(result, @i18n.t("lang.source_file_label", args={ "path": path }))
  // 目标文件
  print_to(result, @i18n.t("lang.dest_file_label", args={ "path": dest_path }))
  // 翻译键数量
  print_to(
    result,
    @i18n.t("lang.translation_count_label", args={
      "count": map.length().to_string(),
    }),
  )
  result
}

///|
/// 执行 lang list 命令：列出所有可用语言
async fn run_lang_list() -> CommandResult {
  let result = CommandResult::success()
  // 可用语言
  print_to(result, @i18n.t("lang.list_title"))
  // 内置语言
  print_to(result, "")
  // 内置语言
  print_to(result, @i18n.t("lang.builtin_lang_label"))
  print_to(result, @i18n.t("lang.zh_desc"))
  print_to(result, @i18n.t("lang.en_desc"))
  // 外部语言：扫描 MVM_HOME/langs 目录中的 JSON 文件
  let external_langs : Array[String] = []
  try {
    let mvm_home = @tools.mvm_home()
    let langs_dir = @fs_ext.join_path(mvm_home, "langs")
    if @fs.exists(langs_dir) {
      // 读取目录中的文件列表
      let entries = @fs.readdir(langs_dir)
      for entry in entries {
        // 仅提取 .json 文件的语言代码
        if entry.has_suffix(".json") {
          let code = entry[0:entry.length() - 5].to_owned()
          let lower = code.to_lower()
          // 排除内置语言
          if lower != "zh" &&
            lower != "zh-cn" &&
            lower != "en" &&
            lower != "en-us" {
            external_langs.push(code)
          }
        }
      }
    }
  } catch {
    // MVM_HOME 不存在或目录读取失败，忽略错误，仅显示内置语言
    _ => ()
  }
  print_to(result, "")
  if external_langs.is_empty() {
    // 外部语言未安装
    print_to(result, @i18n.t("lang.external_not_installed"))
  } else {
    // 外部语言
    print_to(result, @i18n.t("lang.external_label"))
    for code in external_langs {
      print_to(result, "  \{code}")
    }
  }
  // 当前语言
  print_to(result, "")
  // 当前语言
  print_to(
    result,
    @i18n.t("lang.current_lang_label", args={
      "code": @i18n.current_lang_code(),
    }),
  )
  result
}

///|
/// 执行 lang set 命令：设置当前语言（等同 mvm config set language，但允许扩展语言代码）
async fn run_lang_set(code : String) -> CommandResult {
  let result = CommandResult::success()
  // 保存语言配置到 GlobalConfig
  let (_, existing_config) = @tools.get_global_config()
  let new_config = @tools.make_global_config(
    existing_config~,
    language=Some(code),
  )
  let config_path = @tools.save_global_config(new_config)
  // 初始化 i18n，使新语言立即生效
  @i18n.init_lang(Some(code))
  // 配置已保存
  print_to(result, @i18n.t("config.saved_to", args={ "path": config_path }))
  // 语言已设置
  print_to(result, @i18n.t("lang.set_success", args={ "code": code }))
  result
}

///|
/// 执行 lang remove 命令：移除外部语言包
async fn run_lang_remove(code : String) -> CommandResult {
  let result = CommandResult::success()
  let lower = code.to_lower()
  // 内置语言不允许移除
  if lower == "zh" || lower == "zh-cn" || lower == "en" || lower == "en-us" {
    // 不能移除内置语言
    raise fail(@i18n.t("lang.cannot_override_builtin", args={ "lang": code }))
  }
  // 从 MVM_HOME/langs 删除 JSON 文件
  let mvm_home = @tools.mvm_home()
  let langs_dir = @fs_ext.join_path(mvm_home, "langs")
  let json_path = @fs_ext.join_path(langs_dir, code + ".json")
  if !@fs.exists(json_path) {
    // 语言包未安装
    raise fail(@i18n.t("lang.lang_not_installed", args={ "code": code }))
  }
  @fs.remove(json_path) catch {
    // 删除文件失败
    _ =>
      raise fail(@i18n.t("lang.delete_file_failed", args={ "path": json_path }))
  }
  // 清除缓存
  @i18n.remove_external_dict(code)
  // 已移除语言包
  print_to(result, @i18n.t("lang.remove_success", args={ "lang": code }))
  // 删除文件
  print_to(
    result,
    @i18n.t("lang.deleted_file_label", args={ "path": json_path }),
  )
  result
}
