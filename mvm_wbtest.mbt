// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "get_command=install node@lts" {
  let argv = ["install", "node@lts"]
  let command = get_command(argv)
  inspect(
    command,
    content=(
      #|Install(Node, Version("lts"))
    ),
  )
}

///|
test "get_command=install node@latest" {
  let argv = ["install", "node@latest"]
  let command = get_command(argv)
  inspect(
    command,
    content=(
      #|Install(Node, Version("latest"))
    ),
  )
}

///|
test "get_command=install node@23" {
  let argv = ["install", "node@23"]
  let command = get_command(argv)
  inspect(
    command,
    content=(
      #|Install(Node, Version("23"))
    ),
  )
}
