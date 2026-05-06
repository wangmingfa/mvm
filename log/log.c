#include <stdio.h>

void clear_print() {
    printf("\033[2J\033[H");
}

int main () {
    printf("\033[31m红 \033[34m蓝\033[39m 红\033[39m");
    return 0;
}