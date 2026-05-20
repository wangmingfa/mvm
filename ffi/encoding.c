// encoding.c
// 此文件代码只支持windows

#ifdef _WIN32

#include <stdio.h>
#include <windows.h>
#include <stdlib.h>
#include "moonbit.h"

moonbit_string_t make_moonbit_str(const char *utf8)
{
    int wlen = MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        utf8,
        -1,
        NULL,
        0);

    if (wlen <= 0) {
        return NULL;
    }

    // ❗关键：必须用 runtime allocator
    moonbit_string_t out = moonbit_make_string(wlen - 1, 0);

    if (!out) {
        return NULL;
    }

    MultiByteToWideChar(
        CP_UTF8,
        MB_ERR_INVALID_CHARS,
        utf8,
        -1,
        (LPWSTR)out,
        wlen);

    return out;
}

moonbit_string_t *gbk_to_utf8(const char *gbk)
{
    // GBK -> UTF16
    int wlen = MultiByteToWideChar(
        936,
        0,
        gbk,
        -1,
        NULL,
        0);

    if (wlen <= 0)
        return NULL;

    wchar_t *wstr =
        (wchar_t *)malloc(wlen * sizeof(wchar_t));

    if (!wstr)
        return NULL;

    MultiByteToWideChar(
        936,
        0,
        gbk,
        -1,
        wstr,
        wlen);

    // UTF16 -> UTF8
    int utf8_len = WideCharToMultiByte(
        CP_UTF8,
        0,
        wstr,
        -1,
        NULL,
        0,
        NULL,
        NULL);

    char *utf8 =
        (char *)malloc(utf8_len);

    if (!utf8)
    {
        free(wstr);
        return NULL;
    }

    WideCharToMultiByte(
        CP_UTF8,
        0,
        wstr,
        -1,
        utf8,
        utf8_len,
        NULL,
        NULL);

    free(wstr);

    return make_moonbit_str(utf8);
}

#endif
