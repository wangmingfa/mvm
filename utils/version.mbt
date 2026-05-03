///|
pub fn parse_version(version : String) -> FixedArray[Int] raise {
  if version =~ (re"[0-9]+\.[0-9]+(\.[0-9]+)*" as version) {
    let arr = version.split(".").to_array().map(v => @string.parse_int(v))
    return FixedArray::from_array(arr)
  }
  raise fail("无效的版本：\{version}")
  // lexmatch version {
  //   (_, "[[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)*" as version, _) => {
  //     let arr = version.split(".").to_array().map(v => @string.parse_int(v))
  //     FixedArray::from_array(arr)
  //   }
  //   _ => raise fail("无效的版本：\{version}")
  // }
}

///|
test "parse_version" {
  inspect(
    parse_version("v2.3.2"),
    content=(
      #|[2, 3, 2]
    ),
  )
  inspect(
    parse_version("v21.3.20"),
    content=(
      #|[21, 3, 20]
    ),
  )
  inspect(
    parse_version("v2.3111.2"),
    content=(
      #|[2, 3111, 2]
    ),
  )
  inspect(
    parse_version("v1.2.3-dev-alpha"),
    content=(
      #|[1, 2, 3]
    ),
  )
}

///|
pub fn compare_version(version1 : String, version2 : String) -> Int raise {
  let version1s = parse_version(version1)
  let len1 = version1s.length()
  let version2s = parse_version(version2)
  let len2 = version2s.length()
  let len = @cmp.maximum(len1, len2)
  for i in 0..<len {
    if len1 <= i {
      return -1
    }
    if len2 <= i {
      return 1
    }
    if version1s[i] > version2s[i] {
      return 1
    }
    if version1s[i] < version2s[i] {
      return -1
    }
  }
  0
}

///|
test "compare_version" {
  inspect(
    compare_version("1.2.3", "1.2"),
    content=(
      #|1
    ),
  )
  inspect(
    compare_version("v2.1", "2.2"),
    content=(
      #|-1
    ),
  )
  inspect(
    compare_version("1.0", "1.1"),
    content=(
      #|-1
    ),
  )
  inspect(
    compare_version("1.1.1", "1.1.1"),
    content=(
      #|0
    ),
  )
}
