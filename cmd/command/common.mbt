///|
const INSTALLED_FILE = "installed.json"

///|
fn get_installed_file_path() -> String {
  @fs_ext.join_path(@tools.mvm_home(), INSTALLED_FILE)
}

///|
async fn add_installed(tool : Tool, version : String) -> Unit {
  let installed_file_path = get_installed_file_path()
  let json = if @fs.exists(installed_file_path) {
    @fs.read_file(installed_file_path).json() catch {
      e => {
        println(
          "文件 \{@utils.yellow(installed_file_path)} 不是有效的json格式",
        )
        raise e
      }
    }
  } else {
    {}
  }
  guard json is Object(map) else {
    // TODO 如何自动修复格式
    raise fail("文件 \{@utils.yellow(installed_file_path)} 格式不对")
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
    e => {
      println(
        "文件 \{@utils.yellow(installed_file_path)} 不是有效的json格式",
      )
      raise e
    }
  }
  guard json is Object(map) else {
    raise fail("文件 \{@utils.yellow(installed_file_path)} 格式不对")
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
