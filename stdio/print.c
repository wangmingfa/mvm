#include <stdio.h>
#include <string.h>
#include <stdlib.h>

void print(const char* s) {
    printf("%s", s);
}

// 从标准输入读取一行，返回分配的字符串（调用者负责释放）
const char* read_line() {
    char buffer[1024];
    if (fgets(buffer, sizeof(buffer), stdin) == NULL) {
        return strdup("");
    }
    // 去除末尾的换行符
    int len = strlen(buffer);
    if (len > 0 && buffer[len - 1] == '\n') {
        buffer[len - 1] = '\0';
        len--;
    }
    return strdup(buffer);
}

// 刷新 stdout 缓冲区，确保进度条等不带换行的输出立即显示
void flush_stdout() {
    fflush(stdout);
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