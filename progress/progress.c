#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

static void format_size(int64_t bytes, char* buf, size_t buf_size) {
    if (bytes < 1000LL) {
        snprintf(buf, buf_size, "%" PRId64 " B", bytes);
    } else if (bytes < 1000000LL) {
        snprintf(buf, buf_size, "%" PRId64 ".%" PRId64 " KB", bytes / 1000, (bytes * 10 / 1000) % 10);
    } else if (bytes < 1000000000LL) {
        snprintf(buf, buf_size, "%" PRId64 ".%" PRId64 " MB", bytes / 1000000, (bytes * 10 / 1000000) % 10);
    } else {
        snprintf(buf, buf_size, "%" PRId64 ".%" PRId64 " GB", bytes / 1000000000, (bytes * 10 / 1000000000) % 10);
    }
}

void progress_bar(int64_t progress, int64_t total, const char* suffix) {
    if (progress > total) {
        progress = total;
    }
    if (total <= 0) return;

    int bar_width = 50;
    int pos = (int)((progress * bar_width) / total);

    // 刷新 stdout，确保 MoonBit 的 println 等输出先于进度条显示
    fflush(stdout);

    // 使用 stderr（默认无缓冲），避免与 stdout/tty 的顺序问题
    // \r 回到行首，\033[K 清除光标到行尾
    fprintf(stderr, "\r\033[K[");

    for (int i = 0; i < bar_width; i++) {
        if (i < pos) fputc('=', stderr);
        else if (i == pos) fputc('>', stderr);
        else fputc(' ', stderr);
    }

    char progress_str[32], total_str[32];
    format_size(progress, progress_str, sizeof(progress_str));
    format_size(total, total_str, sizeof(total_str));
    fprintf(stderr, "] %s / %s  (%" PRId64 "%%)  %s", progress_str, total_str, (progress * 100) / total, suffix ? suffix : "");
}

void clear_progress() {
    fprintf(stderr, "\r\033[K");
}