#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <moonbit.h>

#ifdef _WIN32
  #include <windows.h>
  #include <winioctl.h>

  // REPARSE_DATA_BUFFER is only defined in ntifs.h (WDK), define it here
  typedef struct _REPARSE_DATA_BUFFER {
    ULONG  ReparseTag;
    USHORT ReparseDataLength;
    USHORT Reserved;
    union {
      struct {
        USHORT SubstituteNameOffset;
        USHORT SubstituteNameLength;
        USHORT PrintNameOffset;
        USHORT PrintNameLength;
        ULONG  Flags;
        WCHAR  PathBuffer[1];
      } SymbolicLinkReparseBuffer;
      struct {
        USHORT SubstituteNameOffset;
        USHORT SubstituteNameLength;
        USHORT PrintNameOffset;
        USHORT PrintNameLength;
        WCHAR  PathBuffer[1];
      } MountPointReparseBuffer;
      struct {
        UCHAR  DataBuffer[1];
      } GenericReparseBuffer;
    };
  } REPARSE_DATA_BUFFER, *PREPARSE_DATA_BUFFER;
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

///|
/// 读取软连接的目标路径，返回 moonbit_bytes_t
/// 如果不是软连接或读取失败，返回长度为 0 的 bytes
MOONBIT_FFI_EXPORT
moonbit_bytes_t readlink_target(const char *path) {
#ifdef _WIN32
    // 打开文件获取句柄
    HANDLE h = CreateFileA(
        path, 0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT,
        NULL
    );
    if (h == INVALID_HANDLE_VALUE) {
        return moonbit_make_bytes(0, 0);
    }

    // 分配足够大的缓冲区存储重解析点数据
    char buffer[MAXIMUM_REPARSE_DATA_BUFFER_SIZE];
    DWORD bytes_returned;
    BOOL ok = DeviceIoControl(
        h, FSCTL_GET_REPARSE_POINT,
        NULL, 0,
        buffer, sizeof(buffer),
        &bytes_returned, NULL
    );
    CloseHandle(h);
    if (!ok) {
        return moonbit_make_bytes(0, 0);
    }

    REPARSE_DATA_BUFFER *rdb = (REPARSE_DATA_BUFFER *)buffer;
    if (rdb->ReparseTag != IO_REPARSE_TAG_SYMLINK) {
        return moonbit_make_bytes(0, 0);
    }

    // 提取目标路径（WCHAR 格式）
    WCHAR *substitute_name = &rdb->SymbolicLinkReparseBuffer.PathBuffer[
        rdb->SymbolicLinkReparseBuffer.SubstituteNameOffset / sizeof(WCHAR)
    ];
    DWORD substitute_len = rdb->SymbolicLinkReparseBuffer.SubstituteNameLength / sizeof(WCHAR);

    /* 跳过 NT 路径前缀 \??\ */
    if (substitute_len > 4 &&
        substitute_name[0] == L'\\' &&
        substitute_name[1] == L'?' &&
        substitute_name[2] == L'?' &&
        substitute_name[3] == L'\\') {
        substitute_name += 4;
        substitute_len -= 4;
    }

    // 转换为 UTF-8
    int utf8_len = WideCharToMultiByte(CP_UTF8, 0, substitute_name, substitute_len, NULL, 0, NULL, NULL);
    if (utf8_len == 0) {
        return moonbit_make_bytes(0, 0);
    }
    moonbit_bytes_t result = moonbit_make_bytes(utf8_len, 0);
    WideCharToMultiByte(CP_UTF8, 0, substitute_name, substitute_len, (char *)result, utf8_len, NULL, NULL);
    return result;
#else
    // 先检查是否是软连接
    struct stat lst;
    if (lstat(path, &lst) == -1 || !S_ISLNK(lst.st_mode)) {
        return moonbit_make_bytes(0, 0);
    }

    // 获取目标路径大小
    ssize_t size = lst.st_size;
    if (size == 0) {
        size = 256;
    }

    char *buf = (char *)malloc(size + 1);
    if (buf == NULL) {
        return moonbit_make_bytes(0, 0);
    }

    ssize_t len = readlink(path, buf, size);
    if (len == -1) {
        free(buf);
        return moonbit_make_bytes(0, 0);
    }
    buf[len] = '\0';

    moonbit_bytes_t result = moonbit_make_bytes(len, 0);
    memcpy((char *)result, buf, len);
    free(buf);
    return result;
#endif
}

// int main() {
//     const char *path = "/Users/11048490/.mvm-test/bin/npm-pkg/vite";

//     int r = symlink_status(path);
//     printf("status = %d\n", r);

//     return 0;
// }