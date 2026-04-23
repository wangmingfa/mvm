#include <string.h> // for strlen
#include "moonbit.h"

static moonbit_string_t make_moonbit_str(const char *s) {
    int32_t len = strlen(s);
    moonbit_string_t ms = moonbit_make_string(len, 0);
    for (int i = 0; i < len; i++) {
        ms[i] = (uint16_t)s[i];
    }
    return ms;
}