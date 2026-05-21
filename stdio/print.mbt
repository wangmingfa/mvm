///|
#borrow(str)
extern "C" fn c_print(str : Bytes) -> Unit = "print"

///|
pub extern "C" fn flush_stdout() -> Unit = "flush_stdout"

///|
pub extern "C" fn clear_lines(lines : Int) -> Unit = "clear_lines"

///|
pub fn print(str : String) -> Unit {
  c_print(@ffi.string_to_c_bytes(str))
}

///|
test "print" {
  print("a")
  print("b")
  print("c")
  print("d")
  print("e")
  println("")
}