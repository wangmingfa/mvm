///|
const INSTALLED_FILE = "installed.json"

///|
fn get_installed_file_path() -> String raise {
  @fs_ext.join_path(@tools.mvm_home(), INSTALLED_FILE)
}

///|
/// installed.json 文件损坏时，自动备份损坏文件并重建空记录
/// 返回重建后的空 JSON Object
async fn recover_installed_file(installed_file_path : String) -> Json {
  let backup_path = installed_file_path + ".bak"
  @log.warn(
    @i18n.t("common.file_format_abnormal_backup", args={"path": @utils.yellow(installed_file_path), "backup": @utils.yellow(backup_path)}),
  )
  // 将损坏文件备份（如果备份文件已存在则覆盖）
  @fs_ext.remove_if_exists(backup_path)
  let mv_result = try? @fs_ext.mv(installed_file_path, backup_path)
  if mv_result is Err(_) {
    @log.warn(@i18n.t("common.backup_failed_delete"))
    @fs_ext.remove_if_exists(installed_file_path)
  }
  // 创建新的空记录文件并返回空 JSON Object
  @fs.write_file(installed_file_path, "{}", create_mode=CreateOrTruncate)
  @json.parse("{}") catch {
    _ => raise fail(@i18n.t("common.cannot_create_empty_json"))
  }
}

///|
async fn add_installed(tool : Tool, version : String) -> Unit {
  let installed_file_path = get_installed_file_path()
  let json = if @fs.exists(installed_file_path) {
    @fs.read_file(installed_file_path).json() catch {
      _ => recover_installed_file(installed_file_path)
    }
  } else {
    {}
  }
  guard json is Object(map) else {
    // 格式不是 Object，自动恢复后重新读取
    let recovered = recover_installed_file(installed_file_path)
    guard recovered is Object(map) else {
      raise fail(
        @i18n.t("common.file_still_wrong_after_recovery", args={"path": @utils.yellow(installed_file_path)}),
      )
    }
    // 恢复成功，使用恢复后的 map 继续写入
    let key = tool.to_string()
    map.set(key, [version])
    let content = Json::object(map).stringify(indent=2)
    @fs.write_file(installed_file_path, content, create_mode=CreateOrTruncate)
    return
  }
  let key = tool.to_string()
  if map.contains(key) {
    let versions = if map.get(tool.to_string()) is Some(v) &&
      v is Array(versions) {
      versions
    } else {
      []
    }
    let version_json_str = Json::string(version)
    if !versions.contains(version_json_str) {
      versions.push(Json::string(version))
    }
  } else {
    map.set(key, [version])
  }
  let content = Json::object(map).stringify(indent=2)
  @fs.write_file(installed_file_path, content, create_mode=CreateOrTruncate)
}

///|
async fn remove_installed(
  tool : Tool,
  remove_versions : Array[String],
) -> Array[String] {
  let installed_file_path = get_installed_file_path()
  if !@fs.exists(installed_file_path) {
    return []
  }
  let json = @fs.read_file(installed_file_path).json() catch {
    _ => recover_installed_file(installed_file_path)
  }
  guard json is Object(map) else {
    // 格式不是 Object，自动恢复后返回空结果（remove 操作无需再处理）
    let _ = recover_installed_file(installed_file_path)
    return []
  }
  let key = tool.to_string()
  if map.contains(key) {
    let versions = if map.get(key) is Some(v) && v is Array(versions) {
      versions
    } else {
      return []
    }
    let removed_versions = []
    for remove_version in remove_versions {
      let version_json = Json::string(remove_version)
      guard versions.search(version_json) is Some(idx) else { continue }
      let _ = versions.remove(idx)
      removed_versions.push(remove_version)
      if versions.length() == 0 {
        map.remove(key)
      }
    }
    let content = Json::object(map).stringify(indent=2)
    @fs.write_file(installed_file_path, content, create_mode=CreateOrTruncate)
    return removed_versions
  }
  return []
}

///|
async fn get_installed(tool : Tool) -> Array[String] {
  let installed_file_path = get_installed_file_path()
  if !@fs.exists(installed_file_path) {
    return []
  }
  let json = @fs.read_file(installed_file_path).json() catch { _ => return [] }
  guard json is Object(map) else { return [] }
  let key = tool.to_string()
  if map.get(key) is Some(v) && v is Array(versions) {
    let result : Array[String] = []
    for ver in versions {
      guard ver is String(s) else { continue }
      result.push(s)
    }
    result
  } else {
    []
  }
}