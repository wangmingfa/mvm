///|
extern "C" fn c_os_name() -> String = "os_name"

///|
extern "C" fn c_os_arch() -> String = "os_arch"

///|
pub enum OS {
  MacOS
  Linux
  Windows
  FreeBSD
  OpenBSD
  NetBSD
  DragonFly
  Solaris
  Haiku
  Unknown(String)
} derive(Debug, Eq)

///|
pub impl Show for OS with output(self, logger) {
  match self {
    MacOS => logger.write_string("MacOS")
    Linux => logger.write_string("Linux")
    Windows => logger.write_string("Windows")
    FreeBSD => logger.write_string("FreeBSD")
    OpenBSD => logger.write_string("OpenBSD")
    NetBSD => logger.write_string("NetBSD")
    DragonFly => logger.write_string("DragonFly")
    Solaris => logger.write_string("Solaris")
    Haiku => logger.write_string("Haiku")
    Unknown(s) => logger.write_string(s)
  }
}

///|
pub enum Arch {
  X86_64
  X86
  Aarch64
  Arm
  Riscv64
  Riscv32
  Loongarch64
  Mips64
  Mips
  Ppc64
  Ppc
  S390x
  Unknown(String)
} derive(Debug, Eq)

///|
pub impl Show for Arch with output(self, logger) {
  match self {
    X86_64 => logger.write_string("X86_64")
    X86 => logger.write_string("X86")
    Aarch64 => logger.write_string("Aarch64")
    Arm => logger.write_string("Arm")
    Riscv64 => logger.write_string("Riscv64")
    Riscv32 => logger.write_string("Riscv32")
    Loongarch64 => logger.write_string("Loongarch64")
    Mips64 => logger.write_string("Mips64")
    Mips => logger.write_string("Mips")
    Ppc64 => logger.write_string("Ppc64")
    Ppc => logger.write_string("Ppc")
    S390x => logger.write_string("S390x")
    Unknown(s) => logger.write_string(s)
  }
}

///|
pub fn get_os_name() -> OS {
  let name = c_os_name()
  match name {
    "macos" => MacOS
    "linux" => Linux
    "windows" => Windows
    "freebsd" => FreeBSD
    "openbsd" => OpenBSD
    "netbsd" => NetBSD
    "dragonfly" => DragonFly
    "solaris" => Solaris
    "haiku" => Haiku
    other => Unknown(other)
  }
}

///|
pub fn get_os_arch() -> Arch {
  let arch = c_os_arch()
  match arch {
    "x86_64" => X86_64
    "x86" => X86
    "aarch64" => Aarch64
    "arm" => Arm
    "riscv64" => Riscv64
    "riscv32" => Riscv32
    "loongarch64" => Loongarch64
    "mips64" => Mips64
    "mips" => Mips
    "ppc64" => Ppc64
    "ppc" => Ppc
    "s390x" => S390x
    other => Unknown(other)
  }
}

///|
pub struct OsInfo {
  name : OS
  arch : Arch
}

///|
pub fn get_os_info() -> OsInfo {
  { name: get_os_name(), arch: get_os_arch() }
}

///|
test "os_name" {
  inspect(
    get_os_name(),
    content=(
      #|MacOS
    ),
  )
}

///|
test "os_arch" {
  inspect(
    get_os_arch(),
    content=(
      #|Aarch64
    ),
  )
}
