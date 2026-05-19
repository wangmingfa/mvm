// MoonBit Runtime 头文件
#include "moonbit.h"

/* ============================================================
 * UTF8 -> MoonBit String
 * ============================================================ */

static moonbit_string_t make_moonbit_str(const char *s)
{
    int len = (int)strlen(s);

    moonbit_string_t out = moonbit_make_string(len, 0);

    int i = 0;
    int o = 0;

    while (i < len) {
        unsigned char c = (unsigned char)s[i];

        if (c < 0x80) {
            out[o++] = c;
            i += 1;
        }
        else if ((c >> 5) == 0x6) {
            uint16_t code =
                ((s[i] & 0x1F) << 6) |
                (s[i + 1] & 0x3F);

            out[o++] = code;
            i += 2;
        }
        else if ((c >> 4) == 0xE) {
            uint16_t code =
                ((s[i] & 0x0F) << 12) |
                ((s[i + 1] & 0x3F) << 6) |
                (s[i + 2] & 0x3F);

            out[o++] = code;
            i += 3;
        }
        else {
            /* 跳过4字节UTF8（emoji等） */
            i += 4;
        }
    }

    return out;
}