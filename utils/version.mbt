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
  // 测试 parse_version 的各版本号解析结果
  let arr = parse_version("v2.3.2")
  guard arr.length() == 3 else { fail("expected 3 segments") }
  guard arr[0] == 2 && arr[1] == 3 && arr[2] == 2 else {
    fail("values mismatch")
  }

  let arr2 = parse_version("v21.3.20")
  guard arr2[0] == 21 && arr2[1] == 3 && arr2[2] == 20 else {
    fail("values mismatch")
  }

  let arr3 = parse_version("v2.3111.2")
  guard arr3[0] == 2 && arr3[1] == 3111 && arr3[2] == 2 else {
    fail("values mismatch")
  }

  let arr4 = parse_version("v1.2.3-dev-alpha")
  guard arr4[0] == 1 && arr4[1] == 2 && arr4[2] == 3 else {
    fail("values mismatch")
  }
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

///|
test "compare_version 边界情况" {
  // 较长版本 vs 较短版本：1.0.0 比 1.0 多一个段，视为更大
  inspect(
    compare_version("1.0.0", "1.0"),
    content=(
      #|1
    ),
  )
  // 大版本号比较
  inspect(
    compare_version("20.0.0", "18.0.0"),
    content=(
      #|1
    ),
  )
  // 两段版本号：第一位相同，第二位决定
  inspect(
    compare_version("1.2", "1.10"),
    content=(
      #|-1
    ),
  )
}

///|
test "parse_version 错误输入" {
  // 空字符串 → 报错
  guard (try? parse_version("")) is Err(_) else {
    fail("空字符串应报错")
  }

  // 纯字母 → 报错
  guard (try? parse_version("abc")) is Err(_) else {
    fail("纯字母应报错")
  }

  // 单段数字（正则要求至少两段，所以"1"是无效的）
  guard (try? parse_version("1")) is Err(_) else {
    fail("单段数字应报错（正则要求至少两段）")
  }

  // 两段版本号（有效）
  guard (try? parse_version("1.2")) is Ok(arr2) else {
    fail("两段版本号应成功")
  }
  guard arr2[0] == 1 && arr2[1] == 2 else {
    fail("两段版本号解析值不正确")
  }
}