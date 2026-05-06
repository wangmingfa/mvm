#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

int symlink_status(const char *path) {
    struct stat st;

    // 0：连路径都不存在
    if (lstat(path, &st) == -1) {
        return 0;
    }

    // 不是软链接（你可以按需决定是否也算 0）
    if (!S_ISLNK(st.st_mode)) {
        return 0;
    }

    // 是软链接，但目标不存在（坏链）
    if (stat(path, &st) == -1) {
        return 1;
    }

    // 软链接 + 目标存在
    return 2;
}

// int main() {
//     const char *path = "/Users/11048490/.mvm-test/bin/npm-pkg/vite";

//     int r = symlink_status(path);
//     printf("status = %d\n", r);

//     return 0;
// }