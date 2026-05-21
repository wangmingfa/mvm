#include <stdio.h>

#ifdef _WIN32
  #include <windows.h>

// 启用 Windows 10+ 虚拟终端（ANSI 转义序列支持）
static void enable_virtual_terminal() {
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut == INVALID_HANDLE_VALUE) return;
    DWORD mode = 0;
    if (!GetConsoleMode(hOut, &mode)) return;
    SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
}
#endif

// 进入备用屏幕
void enter_alternate_screen() {
#ifdef _WIN32
    enable_virtual_terminal();
#endif
    printf("\033[?1049h\033[2J\033[H");
    fflush(stdout);
}

// 退出备用屏幕
void exit_alternate_screen() {
#ifdef _WIN32
    enable_virtual_terminal();
#endif
    printf("\033[?1049l");
    fflush(stdout);
}
