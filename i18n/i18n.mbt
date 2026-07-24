///|
/// 语言类型（仅内置语言）
pub enum Lang {
  Zh // 中文简体 (zh-CN)
  En // 美式英文 (en-US)
} derive(Eq)

///|
/// Lang 转字符串
pub fn Lang::to_string(self : Self) -> String {
  match self {
    Zh => "zh"
    En => "en"
  }
}

///|
/// 字符串转 Lang（未知代码返回 En，内置枚举仅包含 zh/en）
pub fn Lang::from_string(s : String) -> Lang {
  match s.to_lower() {
    "zh" | "zh-cn" => Zh
    "en" | "en-us" => En
    _ => En
  }
}

///|
/// 当前语言代码（可变状态，默认 "en"）
let _current_lang_code : Ref[String] = Ref("en")

///|
/// 已缓存的外部字典（从 MVM_HOME/langs 的 JSON 文件加载）
let _external_dicts : Ref[Map[String, Map[String, String]]] = Ref(Map([]))

///|
/// 外部语言字典目录路径（由 main.mbt 在初始化时通过 set_langs_dir 设置为 MVM_HOME/langs）
/// 未设置时回退到 exe 目录
let _langs_dir : Ref[String?] = Ref(None)

///|
/// 设置外部语言字典目录路径（供 main.mbt 初始化调用）
pub fn set_langs_dir(dir : String) -> Unit {
  _langs_dir.val = Some(dir)
}

///|
/// 获取外部语言字典目录路径
/// 优先使用已设置的 langs_dir（MVM_HOME/langs），未设置时回退到 exe 同目录
pub fn get_langs_dir() -> String {
  match _langs_dir.val {
    Some(dir) => dir
    None => get_exe_dir()
  }
}

///|
/// 获取当前内置语言枚举
pub fn current_lang() -> Lang {
  Lang::from_string(_current_lang_code.val)
}

///|
/// 获取当前语言代码（支持扩展语言代码如 "ja"）
pub fn current_lang_code() -> String {
  _current_lang_code.val
}

///|
/// 获取所有可用内置语言列表
pub fn available_langs() -> Array[Lang] {
  [Zh, En]
}

///|
/// 初始化语言设置：从 GlobalConfig.language 或环境变量推断，并预加载外部字典
pub async fn init_lang(lang_code : String?) -> Unit {
  let lang_code = match lang_code {
    Some(code) => code
    None => _detect_lang_from_env()
  }
  _current_lang_code.val = lang_code
  // 如果不是内置语言，尝试加载外部 JSON 字典
  let lower = lang_code.to_lower()
  if lower != "zh" && lower != "zh-cn" && lower != "en" && lower != "en-us" {
    _load_external_dict(lang_code)
  }
}

///|
/// 从系统环境变量推断语言（仅映射到内置 zh/en）
fn _detect_lang_from_env() -> String {
  let lang_env : String? = match @env.get_env_var("LANG") {
    Some(v) => Some(v)
    None => @env.get_env_var("LC_ALL")
  }
  match lang_env {
    Some(env_val) =>
      if env_val.has_prefix("zh") || env_val.contains("zh_CN") {
        "zh"
      } else {
        "en"
      }
    None => "en"
  }
}

///|
/// 从 langs_dir 加载外部 JSON 字典并缓存
/// langs_dir 优先为 MVM_HOME/langs，回退为 exe 同目录
async fn _load_external_dict(lang_code : String) -> Unit {
  let langs_dir = get_langs_dir()
  let json_path = @fs_ext.join_path(langs_dir, lang_code + ".json")
  if @fs.exists(json_path) {
    try {
      let content = @fs.read_file(json_path)
      let json = content.json()
      // 使用 @json.from_json 直接转换为 Map[String, String]
      let dict : Map[String, String] = @json.from_json(json) catch {
        _ => return // JSON 格式无效，静默忽略
      }
      _external_dicts.val.set(lang_code, dict)
    } catch {
      _ => () // 其他错误也静默忽略，回退到内置字典
    }
  }
}

///|
/// 获取 exe 所在目录（从 args[0] 推断）
pub fn get_exe_dir() -> String {
  let args = @env.args()
  if args.length() > 0 {
    let exe_path = args[0].to_string()
    // 如果路径包含目录分隔符，提取父目录
    if exe_path.contains("/") || exe_path.contains("\\") {
      let exe_path = @fs_ext.canonicalize_path(exe_path)
      let parent : String? = @fs_ext.get_parent_dir(exe_path) catch {
        _ => None
      }
      match parent {
        Some(dir) => dir
        None => _fallback_dir()
      }
    } else {
      // exe 名称不含路径，无法推断目录，使用回退策略
      _fallback_dir()
    }
  } else {
    _fallback_dir()
  }
}

///|
/// 回退目录：优先当前工作目录，否则 "."
fn _fallback_dir() -> String {
  match @env.current_dir() {
    Some(dir) => dir
    None => "."
  }
}

///|
/// 翻译函数：按键查找当前语言的文本，可选参数插值
/// 查找顺序：1. 外部 JSON 字典  2. 内置字典  3. 英文 fallback  4. 返回键本身
/// args 为 {变量名} 占位符提供替换值，缺失参数保留原样
pub fn t(key : String, args? : Map[String, String] = Map([])) -> String {
  let text = _lookup(key, _current_lang_code.val)
  if args.is_empty() {
    text
  } else {
    _interpolate(text, args)
  }
}

///|
/// 内部查找逻辑：按优先级查找翻译
fn _lookup(key : String, lang_code : String) -> String {
  let current_dict = _get_dict(lang_code)
  match current_dict.get(key) {
    Some(value) => value
    None => {
      // 当前语言找不到，回退到英文内置字典
      let lower = lang_code.to_lower()
      if lower != "en" && lower != "en-us" {
        match en_dict.get(key) {
          Some(value) => value
          None => key // 英文也找不到，返回键本身
        }
      } else {
        key // 当前已是英文，返回键本身
      }
    }
  }
}

///|
/// 根据语言代码获取字典
fn _get_dict(lang_code : String) -> Map[String, String] {
  match lang_code.to_lower() {
    "zh" | "zh-cn" => zh_dict
    "en" | "en-us" => en_dict
    _ =>
      // 扩展语言：从缓存的外部字典查找
      match _external_dicts.val.get(lang_code) {
        Some(dict) => dict
        None => Map([]) // 外部字典不存在，回退到 en_dict（由 _lookup 处理）
      }
  }
}

///|
/// 参数插值：替换 {变量名} 占位符，缺失参数保留原样
fn _interpolate(text : String, args : Map[String, String]) -> String {
  let mut result = text
  args.each(fn(key : String, value : String) {
    result = result.replace_all(old="{" + key + "}", new=value)
  })
  result
}

///|
/// 获取所有已安装的语言代码列表（内置 + 外部已加载）
pub fn installed_lang_codes() -> Array[String] {
  let codes : Array[String] = ["zh", "en"]
  _external_dicts.val.each(fn(code : String, _dict : Map[String, String]) {
    codes.push(code)
  })
  codes
}

///|
/// 设置当前语言代码（供外部调用，如 mvm lang 命令测试时使用）
pub fn set_lang(lang_code : String) -> Unit {
  _current_lang_code.val = lang_code
}

///|
/// 加载指定语言的外部 JSON 字典（供 mvm lang install 命令调用后使用）
pub async fn load_external_dict(lang_code : String) -> Unit {
  _load_external_dict(lang_code)
}

///|
/// 移除指定语言的外部字典缓存（供 mvm lang remove 命令使用）
pub fn remove_external_dict(lang_code : String) -> Unit {
  _external_dicts.val.remove(lang_code)
}

///|
/// 检查指定语言代码是否可用（内置或外部已加载）
pub fn is_lang_available(lang_code : String) -> Bool {
  let lower = lang_code.to_lower()
  lower == "zh" ||
  lower == "zh-cn" ||
  lower == "en" ||
  lower == "en-us" ||
  _external_dicts.val.contains(lang_code)
}

///|
test "字典完整性：zh_dict 和 en_dict 键集合一致" {
  // 收集 zh_dict 中 en_dict 缺少的键
  let missing_in_en : Array[String] = []
  zh_dict.each(fn(key, _value) {
    if en_dict.get(key) is None {
      missing_in_en.push(key)
    }
  })
  // 收集 en_dict 中 zh_dict 缺少的键
  let missing_in_zh : Array[String] = []
  en_dict.each(fn(key, _value) {
    if zh_dict.get(key) is None {
      missing_in_zh.push(key)
    }
  })
  guard missing_in_en.is_empty() else {
    fail("en_dict 缺少以下键: \{missing_in_en.join(", ")}")
  }
  guard missing_in_zh.is_empty() else {
    fail("zh_dict 缺少以下键: \{missing_in_zh.join(", ")}")
  }
}

///|
test "翻译查找：zh 和 en 本本键" {
  set_lang("zh")
  guard t("help.usage") == "用法:" else {
    fail("zh lookup failed for help.usage")
  }
  set_lang("en")
  guard t("help.usage") == "Usage:" else {
    fail("en lookup failed for help.usage, got: \{t("help.usage")}")
  }
  set_lang("zh")
}

///|
test "翻译查找：回退到键本身" {
  set_lang("en")
  guard t("nonexistent.key") == "nonexistent.key" else {
    fail("fallback to key failed, got: \{t("nonexistent.key")}")
  }
  set_lang("zh")
}

///|
test "参数插值" {
  set_lang("zh")
  let result = t("install.already_installed", args={
    "tool": "node",
    "version": "v20",
  })
  guard result == "node@v20 已安装" else {
    fail("zh interpolation failed, got: \{result}")
  }
  set_lang("en")
  let result = t("install.already_installed", args={
    "tool": "node",
    "version": "v20",
  })
  guard result == "node@v20 is already installed" else {
    fail("en interpolation failed, got: \{result}")
  }
  // 缺失参数保留原样
  let result = t("install.already_installed", args={ "tool": "node" })
  guard result == "node@{version} is already installed" else {
    fail("missing param should keep placeholder, got: \{result}")
  }
  set_lang("en") // restore default
}

///|
test "Lang 枚举转换" {
  guard Lang::from_string("zh") == Zh else { fail("from_string zh") }
  guard Lang::from_string("zh-CN") == Zh else { fail("from_string zh-CN") }
  guard Lang::from_string("en") == En else { fail("from_string en") }
  guard Lang::from_string("en-US") == En else { fail("from_string en-US") }
  guard Lang::from_string("ja") == En else {
    fail("from_string ja should return En")
  }
  guard Lang::Zh.to_string() == "zh" else { fail("Zh to_string") }
  guard Lang::En.to_string() == "en" else { fail("En to_string") }
}
