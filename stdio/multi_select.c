// multi_select.c
// Linux/macOS/Windows10+
// gcc multi_select.c -o multi_select
// cl multi_select.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <conio.h>
#else
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <errno.h>
#endif

#define MAX_ITEMS 128

enum {
    KEY_NONE,
    KEY_UP,
    KEY_DOWN,
    KEY_SPACE,
    KEY_ENTER,
    KEY_QUIT,
    KEY_SELECT_ALL,
    KEY_INVERT
};

typedef struct {
    char* text;
    int checked;
} Item;

#ifdef _WIN32

static DWORD original_in_mode;
static DWORD original_out_mode;

void enable_raw_mode() {
    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleMode(hIn, &original_in_mode);
    GetConsoleMode(hOut, &original_out_mode);

    DWORD in_mode = original_in_mode;

    in_mode &= ~(ENABLE_ECHO_INPUT |
                 ENABLE_LINE_INPUT |
                 ENABLE_PROCESSED_INPUT);

    SetConsoleMode(hIn, in_mode);

    DWORD out_mode =
        original_out_mode |
        ENABLE_VIRTUAL_TERMINAL_PROCESSING;

    SetConsoleMode(hOut, out_mode);

    SetConsoleOutputCP(CP_UTF8);
}

void disable_raw_mode() {
    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);

    SetConsoleMode(hIn, original_in_mode);
    SetConsoleMode(hOut, original_out_mode);
}

int read_key() {
    int c = _getch();

    if (c == 224 || c == 0) {
        int k = _getch();

        switch (k) {
            case 72: return KEY_UP;
            case 80: return KEY_DOWN;
        }
    }

    switch (c) {
        case 'k': return KEY_UP;
        case 'j': return KEY_DOWN;
        case ' ': return KEY_SPACE;
        case 'q': return KEY_QUIT;
        case 'a': return KEY_SELECT_ALL;
        case 'i': return KEY_INVERT;
        case 13:  return KEY_ENTER;
    }

    return KEY_NONE;
}

#else

static struct termios original_termios;

void enable_raw_mode() {
    // 清除 stdin 的 O_NONBLOCK 标志，防止后续 read() 因非阻塞返回 EAGAIN
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (flags != -1) {
        fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK);
    }

    tcgetattr(STDIN_FILENO, &original_termios);

    struct termios raw = original_termios;

    raw.c_lflag &= ~(ECHO | ICANON);

    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void disable_raw_mode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &original_termios);
}

int read_key() {
    char c;
    int n;

    // 重试读取，忽略 EAGAIN 错误（非阻塞模式下无数据可读时返回）
    do {
        n = read(STDIN_FILENO, &c, 1);
    } while (n == -1 && errno == EAGAIN);

    if (n != 1) {
        return KEY_NONE;
    }

    if (c == '\x1b') {
        char seq[2];

        if (read(STDIN_FILENO, &seq[0], 1) != 1) return KEY_NONE;
        if (read(STDIN_FILENO, &seq[1], 1) != 1) return KEY_NONE;

        if (seq[0] == '[') {
            switch (seq[1]) {
                case 'A': return KEY_UP;
                case 'B': return KEY_DOWN;
            }
        }

        return KEY_NONE;
    }

    switch (c) {
        case 'k': return KEY_UP;
        case 'j': return KEY_DOWN;
        case ' ': return KEY_SPACE;
        case 'q': return KEY_QUIT;
        case 'a': return KEY_SELECT_ALL;
        case 'i': return KEY_INVERT;

        case '\r':
        case '\n':
            return KEY_ENTER;
    }

    return KEY_NONE;
}

#endif

static int last_draw_lines = 0;

void clear_screen() {
    printf("\x1b[2J\x1b[H");
}

void move_cursor_home() {
    printf("\x1b[H");
}

void hide_cursor() {
    printf("\x1b[?25l");
}

void show_cursor() {
    printf("\x1b[?25h");
}

void draw(Item* items, int count, int current, const char* title) {

    move_cursor_home();
    
    int lines = 0;
    
    if (title != NULL && *title != '\0') {
        // Title (highlighted with bold + cyan)
        printf("\n\n\x1b[36m");
        printf(">>>>%s", title);
        printf("\x1b[0m\n");
        lines += 3;
    }

    // Key hints (compact, single line)
    printf("\x1b[33m↑↓/jk\x1b[0m:Move  ");
    printf("\x1b[33mSPACE\x1b[0m:Toggle  ");
    printf("\x1b[33ma\x1b[0m:All  ");
    printf("\x1b[33mi\x1b[0m:Invert  ");
    printf("\x1b[33mENTER\x1b[0m:OK  ");
    printf("\x1b[33mq\x1b[0m:Quit\n");
    lines++;

    printf("\x1b[90m");
    printf("----------------------------------------\n");
    printf("\x1b[0m");
    lines++;

    for (int i = 0; i < count; i++) {

        int is_current = (i == current);
        int is_checked = items[i].checked;

        // Cursor highlight (current row)
        if (is_current) {
            printf("\x1b[44m\x1b[97m"); // blue background + white text
            printf(" ❯ ");
        } else {
            printf("   ");
        }

        // Checkbox color
        if (is_checked) {
            printf("\x1b[32m"); // green
            printf("[✔] ");
        } else {
            printf("\x1b[90m"); // gray
            printf("[ ] ");
        }

        // item text
        printf("\x1b[0m"); // reset for text
        printf("%s", items[i].text);

        printf("\x1b[0m");
        printf("\n");
        lines++;
    }

    printf("\x1b[90m----------------------------------------\x1b[0m\n");
    lines++;

    // footer stats
    int selected = 0;
    for (int i = 0; i < count; i++) {
        if (items[i].checked) selected++;
    }

    printf("\x1b[36mSelected:\x1b[0m %d/%d\n", selected, count);
    lines++;

    // Clear any leftover lines from previous draw
    for (int i = lines; i < last_draw_lines; i++) {
        printf("\x1b[K\n");
    }
    
    last_draw_lines = lines;

    fflush(stdout);
}

// ======================================================
// multi_select()
// 输入:
//   "Node.js,Bun,Deno"
//
// 返回:
//   "Node.js,Deno"
//
// 需要 free() 返回值
// ======================================================

char* multi_select(const char* input, const char* preselected, const char* title) {

    Item items[MAX_ITEMS];
    int count = 0;

    char* temp = strdup(input);

    char* token = strtok(temp, ",");

    while (token && count < MAX_ITEMS) {

        items[count].text = strdup(token);
        items[count].checked = 0;

        count++;

        token = strtok(NULL, ",");
    }

    free(temp);

    // 预选中之前保存的工具
    if (preselected && strlen(preselected) > 0) {
        char* pre_copy = strdup(preselected);
        char* pre_token = strtok(pre_copy, ",");
        while (pre_token) {
            for (int i = 0; i < count; i++) {
                if (strcmp(items[i].text, pre_token) == 0) {
                    items[i].checked = 1;
                    break;
                }
            }
            pre_token = strtok(NULL, ",");
        }
        free(pre_copy);
    }

    if (count == 0) {
        return strdup("");
    }

    enable_raw_mode();
    hide_cursor();

    int current = 0;

    while (1) {

        draw(items, count, current, title);

        int key = read_key();

        switch (key) {

            case KEY_UP:
                current--;
                if (current < 0) {
                    current = count - 1;
                }
                break;

            case KEY_DOWN:
                current++;
                if (current >= count) {
                    current = 0;
                }
                break;

            case KEY_SPACE:
                items[current].checked =
                    !items[current].checked;
                break;

            case KEY_SELECT_ALL:
                // 全选：所有项设为选中
                for (int i = 0; i < count; i++) {
                    items[i].checked = 1;
                }
                break;

            case KEY_INVERT:
                // 反选：切换所有项的选中状态
                for (int i = 0; i < count; i++) {
                    items[i].checked = !items[i].checked;
                }
                break;

            case KEY_QUIT:

                show_cursor();
                disable_raw_mode();
                clear_screen();

                for (int i = 0; i < count; i++) {
                    free(items[i].text);
                }

                return strdup("_QUIT_");

            case KEY_ENTER: {

                show_cursor();
                disable_raw_mode();
                clear_screen();

                size_t total = 1;

                for (int i = 0; i < count; i++) {
                    if (items[i].checked) {
                        total += strlen(items[i].text) + 1;
                    }
                }

                char* result = malloc(total);
                result[0] = '\0';

                int first = 1;

                for (int i = 0; i < count; i++) {

                    if (!items[i].checked) {
                        continue;
                    }

                    if (!first) {
                        strcat(result, ",");
                    }

                    strcat(result, items[i].text);

                    first = 0;
                }

                for (int i = 0; i < count; i++) {
                    free(items[i].text);
                }

                return result;
            }
        }
    }
}

// ======================================================

// int main() {

//     char* result =
//         multi_select("Node.js,Bun,Deno,Python,Rust", "Bun,Rust", "请选择：");

//     printf("Selected: %s\n", result);

//     free(result);

//     return 0;
// }