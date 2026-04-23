#include <string.h>
#include "moonbit.h"

static moonbit_string_t make_moonbit_str(const char *s) {
    int32_t len = strlen(s);
    moonbit_string_t ms = moonbit_make_string(len, 0);
    for (int i = 0; i < len; i++) {
        ms[i] = (uint16_t)s[i];
    }
    return ms;
}

moonbit_string_t os_name(void) {
#if defined(__APPLE__)
    return make_moonbit_str("macos");
#elif defined(__linux__)
    return make_moonbit_str("linux");
#elif defined(_WIN32) || defined(_WIN64)
    return make_moonbit_str("windows");
#elif defined(__FreeBSD__)
    return make_moonbit_str("freebsd");
#elif defined(__OpenBSD__)
    return make_moonbit_str("openbsd");
#elif defined(__NetBSD__)
    return make_moonbit_str("netbsd");
#elif defined(__DragonFly__)
    return make_moonbit_str("dragonfly");
#elif defined(__sun) && defined(__SVR4)
    return make_moonbit_str("solaris");
#elif defined(__HAIKU__)
    return make_moonbit_str("haiku");
#else
    return make_moonbit_str("unknown");
#endif
}

moonbit_string_t os_arch(void) {
#if defined(__x86_64__) || defined(_M_X64)
    return make_moonbit_str("x86_64");
#elif defined(__i386__) || defined(_M_IX86)
    return make_moonbit_str("x86");
#elif defined(__aarch64__) || defined(_M_ARM64)
    return make_moonbit_str("aarch64");
#elif defined(__arm__) || defined(_M_ARM)
    return make_moonbit_str("arm");
#elif defined(__riscv) && __riscv_xlen == 64
    return make_moonbit_str("riscv64");
#elif defined(__riscv) && __riscv_xlen == 32
    return make_moonbit_str("riscv32");
#elif defined(__loongarch64)
    return make_moonbit_str("loongarch64");
#elif defined(__mips64)
    return make_moonbit_str("mips64");
#elif defined(__mips__)
    return make_moonbit_str("mips");
#elif defined(__powerpc64__)
    return make_moonbit_str("ppc64");
#elif defined(__powerpc__)
    return make_moonbit_str("ppc");
#elif defined(__s390x__)
    return make_moonbit_str("s390x");
#else
    return make_moonbit_str("unknown");
#endif
}
