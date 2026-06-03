///|
priv struct Path(String)

///|
test "Path" {
  let _ = Path("")
}

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
pub fn[T1 : Show, T2 : Show] join_path(
  current : T1,
  path_to_join : T2,
) -> String {
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
#cfg(not(platform="windows"))
test "join_path unix" {
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
#cfg(platform="windows")
test "join_path windows" {
  inspect(
    join_path("C:\\Users\\wmf\\code\\data.txt", "../"),
    content=(
      #|C:\Users\wmf\code
    ),
  )
  inspect(
    join_path("C:\\Users\\wmf\\code\\data.txt", "../../"),
    content=(
      #|C:\Users\wmf
    ),
  )
}

///|
pub fn[T : Show] join_paths(paths : ArrayView[T]) -> String {
  // 过滤掉空值
  let paths = paths.filter(v => !v.to_string().is_blank())
  if paths.is_empty() {
    return ""
  }
  if paths.length() == 1 {
    return canonicalize_path(paths[0].to_string())
  }
  let rest = paths[1:].map(v => v.to_string()).join("/")
  join_path(paths[0], rest)
}

///|
#cfg(not(platform="windows"))
test "join_paths unix" {
  inspect(
    join_paths(["/home/wmf/code/data.txt", "../", "hello"]),
    content=(
      #|/home/wmf/code/hello
    ),
  )
  inspect(
    join_paths(["/home/wmf/code/data.txt", "../", "", "world", "", ""]),
    content=(
      #|/home/wmf/code/world
    ),
  )
}

///|
#cfg(platform="windows")
test "join_paths windows" {
  inspect(
    join_paths(["C:\\Users\\wmf\\code\\data.txt", "../", "hello"]),
    content=(
      #|C:\Users\wmf\code\hello
    ),
  )
  inspect(
    join_paths(["C:\\Users\\wmf\\code\\data.txt", "../", "", "world", "", ""]),
    content=(
      #|C:\Users\wmf\code\world
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
pub fn canonicalize_path(path : String) -> String {
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
  let result = if is_absolute { "/\{result}" } else { result }
  let result = if result.has_suffix("/") {
    result[0:-1].to_owned()
  } else {
    result
  }
  // Windows 使用 \\ 作为路径分隔符，其它系统使用 /
  match @os.get_os_name() {
    Windows => result.replace_all(old="/", new="\\")
    _ => result
  }
}

///|
#cfg(not(platform="windows"))
test "canonicalize_path unix" {
  inspect(
    canonicalize_path("/home/peter/sticky/../vscode/./code/abc/"),
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
#cfg(platform="windows")
test "canonicalize_path windows" {
  inspect(canonicalize_path("./path/to/text.txt"), content="path\\to\\text.txt")
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
#cfg(not(platform="windows"))
test "canonicalize_path with dot" {
  inspect(
    canonicalize_path("/home/./lily/./spaces"),
    content=(
      #|/home/lily/spaces
    ),
  )
}

///|
#cfg(platform="windows")
test "canonicalize_path with dot windows" {
  inspect(
    canonicalize_path("C:\\Users\\.\\lily\\.\\spaces"),
    content=(
      #|C:\Users\lily\spaces
    ),
  )
}

///|
#cfg(not(platform="windows"))
test "canonicalize_path with dotdot" {
  inspect(
    canonicalize_path("/home/lily/../bob/spaces"),
    content=(
      #|/home/bob/spaces
    ),
  )
}

///|
#cfg(platform="windows")
test "canonicalize_path with dotdot windows" {
  inspect(
    canonicalize_path("C:\\Users\\lily\\..\\bob\\spaces"),
    content=(
      #|C:\Users\bob\spaces
    ),
  )
}

///|
#cfg(not(platform="windows"))
test "canonicalize_path with multiple dotdot" {
  inspect(
    canonicalize_path("/home/lily/spaces/../../bob"),
    content=(
      #|/home/bob
    ),
  )
}

///|
#cfg(platform="windows")
test "canonicalize_path with multiple dotdot windows" {
  inspect(
    canonicalize_path("C:\\Users\\lily\\spaces\\..\\..\\bob"),
    content=(
      #|C:\Users\bob
    ),
  )
}

///|
#cfg(not(platform="windows"))
test "canonicalize_path relative" {
  inspect(
    canonicalize_path("a/b/../c/./d"),
    content=(
      #|a/c/d
    ),
  )
}

///|
#cfg(platform="windows")
test "canonicalize_path relative windows" {
  inspect(
    canonicalize_path("a\\b\\..\\c\\.\\d"),
    content=(
      #|a\c\d
    ),
  )
}

///|
pub fn get_parent_dir(path : String, levels? : Int = 1) -> String? raise {
  guard levels > 0 else {
    raise fail("levels 必须大于 0，当前值：\{levels}")
  }
  let path = path.canonicalize_path()
  // 根据操作系统选择路径分隔符
  let sep = match @os.get_os_name() {
    Windows => "\\"
    _ => "/"
  }
  guard path.contains(sep) else { return None }
  let arr = path.split(sep).to_array()
  for _ in 0..<levels {
    guard arr.length() > 0 else { return None }
    let _ = arr.pop()
  }
  if arr.is_empty() {
    return None
  }
  Some(arr.join(sep))
}

///|
#cfg(not(platform="windows"))
test "get_parent_dir unix" {
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
  debug_inspect(
    get_parent_dir("/home/peter/code/a.txt", levels=2),
    content=(
      #|Some("/home/peter")
    ),
  )
  debug_inspect(
    get_parent_dir("/home/peter/code/a.txt", levels=3),
    content=(
      #|Some("/home")
    ),
  )
  debug_inspect(
    get_parent_dir("/home/peter/code/a.txt", levels=4),
    content=(
      #|Some("")
    ),
  )
  debug_inspect(
    get_parent_dir("/home", levels=1),
    content=(
      #|Some("")
    ),
  )
  debug_inspect(
    get_parent_dir("/home", levels=2),
    content=(
      #|None
    ),
  )
}

///|
#cfg(platform="windows")
test "get_parent_dir windows" {
  debug_inspect(
    get_parent_dir("C:\\Users\\peter\\code"),
    content=(
      #|Some("C:\\Users\\peter")
    ),
  )
  debug_inspect(
    get_parent_dir("C:\\Users\\peter\\code\\a.txt"),
    content=(
      #|Some("C:\\Users\\peter\\code")
    ),
  )
  debug_inspect(
    get_parent_dir("C:\\Users\\peter\\code\\a.txt", levels=2),
    content=(
      #|Some("C:\\Users\\peter")
    ),
  )
  debug_inspect(
    get_parent_dir("C:\\Users\\peter\\code\\a.txt", levels=3),
    content=(
      #|Some("C:\\Users")
    ),
  )
}
