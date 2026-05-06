#include <stdio.h>

#ifdef _WIN32
  #include <windows.h>
#else
  #include <sys/stat.h>
  #include <unistd.h>
#endif

int symlink_status(const char *path) {
#ifdef _WIN32
    // 获取路径属性（不跟随重解析点）
    WIN32_FILE_ATTRIBUTE_DATA attrs;
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &attrs)) {
        return 0; // 路径不存在
    }

    // 不是重解析点（符号链接 / junction）
    if (!(attrs.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
        return 0;
    }

    // 是符号链接，尝试跟随目标打开以验证其是否存在
    HANDLE h = CreateFileA(
        path, 0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS, NULL
    );
    if (h == INVALID_HANDLE_VALUE) {
        return 1; // 坏链（目标不存在）
    }
    CloseHandle(h);
    return 2; // 符号链接 + 目标存在
#else
    struct stat st;

    // 0：路径不存在
    if (lstat(path, &st) == -1) {
        return 0;
    }

    // 不是软链接
    if (!S_ISLNK(st.st_mode)) {
        return 0;
    }

    // 是软链接，但目标不存在（坏链）
    if (stat(path, &st) == -1) {
        return 1;
    }

    // 软链接 + 目标存在
    return 2;
#endif
}

// int main() {
//     const char *path = "/Users/11048490/.mvm-test/bin/npm-pkg/vite";

//     int r = symlink_status(path);
//     printf("status = %d\n", r);

//     return 0;
// }