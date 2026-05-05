///|
pub struct Path(String)

///|
fn Path::join(self : Self, path : String) -> Self {
  let path = self.0.join_path(path)
  Path(path)
}

///|
fn Path::to_string(self : Self) -> String {
  self.0
}

///|
pub fn[T : Show] join_path(current : T, path_to_join : T) -> String {
  let mut path = "\{current}/\{path_to_join}"
  while true {
    let mut continue_loop = false
    for str in ["//", "\\\\", "\\/", "/\\"] {
      if path.contains(str) {
        path = path.replace_all(old=str, new="/")
        continue_loop = false
      }
    }
    if !continue_loop {
      break
    }
  }
  path.canonicalize_path()
}

///|
test "join_path" {
  inspect(
    join_path("/home/wmf/code/data.txt", "../"),
    content=(
      #|/home/wmf/code
    ),
  )
  inspect(
    join_path("/home/wmf/code/data.txt", "../../"),
    content=(
      #|/home/wmf
    ),
  )
}

///|
fn String::join_path(self : Self, path : String) -> Self {
  join_path(self, path)
}

///|
fn String::canonicalize_path(self : Self) -> Self {
  canonicalize_path(self)
}

///|
/// 将路径中的相对路径符号转换，比如: .和..
fn canonicalize_path(path : String) -> String {
  let path = path.replace_all(old="\\", new="/")
  let is_absolute = path.length() > 0 && path[0] == '/'
  let parts = path.split("/")
  let stack : Array[String] = []
  for part in parts {
    let part = part.to_owned()
    if part == "." || part == "" {
      continue
    } else if part == ".." {
      if stack.length() > 0 {
        let _ = stack.pop()
      }
    } else {
      stack.push(part)
    }
  }
  let mut result = ""
  let mut first = true
  for part in stack {
    if first {
      result = part
      first = false
    } else {
      result = "\{result}/\{part}"
    }
  }
  if is_absolute {
    "/\{result}"
  } else {
    result
  }
}

///|
test "canonicalize_path" {
  inspect(
    canonicalize_path("/home/peter/sticky/../vscode/./code/abc"),
    content=(
      #|/home/peter/vscode/code/abc
    ),
  )
  inspect(
    canonicalize_path("peter/sticky/../vscode/./code/abc"),
    content=(
      #|peter/vscode/code/abc
    ),
  )
  inspect(
    canonicalize_path("/home/peter/sticky/../vscode/./code/../../abc"),
    content=(
      #|/home/peter/abc
    ),
  )
}

///|
/// 获取一个路径的名称：如果是文件，则返回文件名；如果是文件夹，则返回文件夹名ing成
pub fn get_path_name(path : String) -> String {
  let paths = path.split("\\").flat_map(v => v.split("/"))
  guard paths.last() is Some(name)
  name.to_owned()
}

///|
test "get_path_name dir" {
  inspect(
    get_path_name("/home/lily/spaces"),
    content=(
      #|spaces
    ),
  )
}

///|
test "get_path_name dir windows" {
  inspect(
    get_path_name("C:\\home\\lily\\spaces"),
    content=(
      #|spaces
    ),
  )
}

///|
test "get_path_name file" {
  inspect(
    get_path_name("/home/lily/spaces/nodejs-arm64-v24.0.1.tar.gz"),
    content=(
      #|nodejs-arm64-v24.0.1.tar.gz
    ),
  )
}

///|
test "get_path_name file windows" {
  inspect(
    get_path_name("C:\\home\\lily/spaces\\nodejs-arm64-v24.0.1.tar.gz"),
    content=(
      #|nodejs-arm64-v24.0.1.tar.gz
    ),
  )
}

///|
test "canonicalize_path with dot" {
  inspect(
    canonicalize_path("/home/./lily/./spaces"),
    content=(
      #|/home/lily/spaces
    ),
  )
}

///|
test "canonicalize_path with dotdot" {
  inspect(
    canonicalize_path("/home/lily/../bob/spaces"),
    content=(
      #|/home/bob/spaces
    ),
  )
}

///|
test "canonicalize_path with multiple dotdot" {
  inspect(
    canonicalize_path("/home/lily/spaces/../../bob"),
    content=(
      #|/home/bob
    ),
  )
}

///|
test "canonicalize_path relative" {
  inspect(
    canonicalize_path("a/b/../c/./d"),
    content=(
      #|a/c/d
    ),
  )
}

///|
test "canonicalize_path windows" {
  inspect(
    canonicalize_path("C:\\home\\lily\\..\\bob"),
    content=(
      #|C:/home/bob
    ),
  )
}

///|
pub fn get_parent_dir(path : String) -> String? {
  let path = path.canonicalize_path()
  guard path.contains("/") else { return None }
  let arr = path.split("/").to_array()
  let _ = arr.pop()
  Some(arr.join("/"))
}

///|
test "get_parent_dir" {
  debug_inspect(
    get_parent_dir("/home/peter/code"),
    content=(
      #|Some("/home/peter")
    ),
  )
  debug_inspect(
    get_parent_dir("home/peter/code"),
    content=(
      #|Some("home/peter")
    ),
  )
  debug_inspect(
    get_parent_dir("home/peter/code/"),
    content=(
      #|Some("home/peter")
    ),
  )
  debug_inspect(
    get_parent_dir("home/peter/code/a.txt"),
    content=(
      #|Some("home/peter/code")
    ),
  )
}
