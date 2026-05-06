#include <stdio.h>
#include <unistd.h>

// 进入备用屏幕
void enter_alternate_screen() {
    printf("\033[?1049h\033[2J\033[H");
    fflush(stdout);
}

// 退出备用屏幕
void exit_alternate_screen() {
    printf("\033[?1049l");
    fflush(stdout);
}
