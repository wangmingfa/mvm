#include <stdio.h>

void print(const char* s) {
    printf("%s", s);
}

// 只清除当前程序输出的 n 行，不影响终端历史输出
void clear_lines(int n)
{
    for (int i = 0; i < n; i++) {
        printf("\033[A");     // 上移
        printf("\r\033[2K");
    }
    fflush(stdout);
}