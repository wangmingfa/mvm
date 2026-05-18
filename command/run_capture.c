#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "moonbit.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#endif

///|
/// 将 null-delimited packed 字符串拆分为 argv 数组
/// packed 格式: "str1\0str2\0str3\0\0" (双 null 结尾)
/// 返回 malloc 分配的 argv 数组 (需要调用者释放)
static char **unpack_args(const char *packed, int *count_out) {
    if (packed == NULL || packed[0] == '\0') {
        char **argv = (char **)malloc(sizeof(char *));
        argv[0] = NULL;
        *count_out = 0;
        return argv;
    }

    // 计算字符串数量
    int count = 0;
    const char *p = packed;
    while (*p != '\0') {
        count++;
        p += strlen(p) + 1; // 跳过当前字符串及其 null 终止符
    }

    // 构建 argv 数组
    char **argv = (char **)malloc((count + 1) * sizeof(char *));
    p = packed;
    for (int i = 0; i < count; i++) {
        argv[i] = (char *)p; // 直接指向 packed 中的字符串（无需单独分配）
        p += strlen(p) + 1;
    }
    argv[count] = NULL;
    *count_out = count;
    return argv;
}

///|
/// 将 null-delimited packed 环境变量拆分为 envp 格式
/// packed 格式: "KEY=VAL\0KEY2=VAL2\0\0" (双 null 结尾)
/// 返回 malloc 分配的数组 (需要调用者释放)
/// 注意: 不修改当前进程环境，仅在子进程 exec 前设置
static char **unpack_envs(const char *packed) {
    if (packed == NULL || packed[0] == '\0') {
        char **envs = (char **)malloc(sizeof(char *));
        envs[0] = NULL;
        return envs;
    }

    int count = 0;
    const char *p = packed;
    while (*p != '\0') {
        count++;
        p += strlen(p) + 1;
    }

    char **envs = (char **)malloc((count + 1) * sizeof(char *));
    p = packed;
    for (int i = 0; i < count; i++) {
        envs[i] = (char *)p;
        p += strlen(p) + 1;
    }
    envs[count] = NULL;
    return envs;
}

#ifndef _WIN32

///|
/// Unix 实现: fork + execvp + pipe
/// 同时流式输出到控制台并捕获 stdout
/// 返回: [4字节 exit_code][output_bytes...]
/// args_packed: "cmd\0arg1\0arg2\0\0" (null-delimited, double-null terminated)
/// envs_packed: "KEY=VAL\0KEY2=VAL2\0\0" (null-delimited, double-null terminated)
MOONBIT_FFI_EXPORT
moonbit_bytes_t mvm_run_with_output(
    moonbit_bytes_t args_packed,
    moonbit_bytes_t envs_packed
) {
    // 拆包参数
    int args_count = 0;
    char **argv = unpack_args((const char *)args_packed, &args_count);
    char **extra_envs = unpack_envs((const char *)envs_packed);

    if (args_count == 0 || argv[0] == NULL) {
        free(argv);
        free(extra_envs);
        // 返回 exit_code=-1, 无输出
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[0] = 0xFF; result[1] = 0xFF; result[2] = 0xFF; result[3] = 0xFF;
        return result;
    }

    // 创建管道
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        free(argv);
        free(extra_envs);
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[3] = 1; // exit_code = 1 (pipe 创建失败)
        return result;
    }

    // fork 子进程
    pid_t pid = fork();
    if (pid == -1) {
        close(pipefd[0]);
        close(pipefd[1]);
        free(argv);
        free(extra_envs);
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[3] = 1; // exit_code = 1 (fork 失败)
        return result;
    }

    if (pid == 0) {
        // 子进程
        close(pipefd[0]); // 关闭读端
        dup2(pipefd[1], STDOUT_FILENO); // stdout 重定向到管道写端
        close(pipefd[1]);

        // 设置额外环境变量
        for (int i = 0; extra_envs[i] != NULL; i++) {
            // 解析 KEY=VALUE 并设置到环境
            char *eq = strchr(extra_envs[i], '=');
            if (eq != NULL) {
                char key_buf[256];
                int key_len = eq - extra_envs[i];
                if (key_len < 256) {
                    memcpy(key_buf, extra_envs[i], key_len);
                    key_buf[key_len] = '\0';
                    setenv(key_buf, eq + 1, 1);
                }
            }
        }

        // 执行命令
        execvp(argv[0], argv);
        // execvp 失败
        _exit(127);
    }

    // 父进程
    close(pipefd[1]); // 关闭写端

    // 从管道读取 stdout，同时流式输出到控制台并捕获到缓冲区
    char read_buf[4096];
    size_t total_len = 0;
    size_t output_cap = 4096;
    char *output_buf = (char *)malloc(output_cap);
    if (output_buf == NULL) {
        close(pipefd[0]);
        free(argv);
        free(extra_envs);
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[3] = 1; // exit_code = 1 (内存分配失败)
        return result;
    }

    ssize_t n;
    while ((n = read(pipefd[0], read_buf, sizeof(read_buf))) > 0) {
        // 流式输出到控制台
        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(STDOUT_FILENO, read_buf + written, n - written);
            if (w <= 0) break;
            written += w;
        }

        // 捕获到缓冲区
        if (total_len + n > output_cap) {
            output_cap = (total_len + n) * 2;
            char *new_buf = (char *)realloc(output_buf, output_cap);
            if (new_buf == NULL) {
                // 内存不足，停止捕获但继续流式输出
                break;
            }
            output_buf = new_buf;
        }
        memcpy(output_buf + total_len, read_buf, n);
        total_len += n;
    }
    close(pipefd[0]);

    // 等待子进程结束
    int status;
    int wait_result;
    do {
        wait_result = waitpid(pid, &status, 0);
    } while (wait_result == -1 && errno == EINTR);

    int exit_code;
    if (wait_result == -1) {
        exit_code = 1; // waitpid 失败
    } else if (WIFEXITED(status)) {
        exit_code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        exit_code = 128 + WTERMSIG(status);
    } else {
        exit_code = 1; // 异常终止
    }

    free(argv);
    free(extra_envs);

    // 构建返回结果: [4字节 exit_code (big-endian)][output_bytes...]
    int32_t result_size = 4 + total_len;
    moonbit_bytes_t result = moonbit_make_bytes(result_size, 0);
    // exit_code 以 big-endian 存储
    result[0] = (exit_code >> 24) & 0xFF;
    result[1] = (exit_code >> 16) & 0xFF;
    result[2] = (exit_code >> 8) & 0xFF;
    result[3] = exit_code & 0xFF;
    if (total_len > 0) {
        memcpy((char *)result + 4, output_buf, total_len);
    }
    free(output_buf);

    return result;
}

#else // _WIN32

///|
/// Windows 实现: 使用 CreateProcess + pipe
/// 返回: [4字节 exit_code][output_bytes...]
MOONBIT_FFI_EXPORT
moonbit_bytes_t mvm_run_with_output(
    moonbit_bytes_t args_packed,
    moonbit_bytes_t envs_packed
) {
    // Windows: 拆包参数，构建命令行字符串
    int args_count = 0;
    char **argv = unpack_args((const char *)args_packed, &args_count);
    char **extra_envs = unpack_envs((const char *)envs_packed);

    if (args_count == 0 || argv[0] == NULL) {
        free(argv);
        free(extra_envs);
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[0] = 0xFF; result[1] = 0xFF; result[2] = 0xFF; result[3] = 0xFF;
        return result;
    }

    // 构建命令行字符串 (需要引号包裹含空格的参数)
    size_t cmd_len = 0;
    for (int i = 0; i < args_count; i++) {
        cmd_len += strlen(argv[i]) + 3; // 可能加引号 + 空格
    }
    char *cmdline = (char *)malloc(cmd_len + 1);
    cmdline[0] = '\0';
    for (int i = 0; i < args_count; i++) {
        if (i > 0) strcat(cmdline, " ");
        if (strchr(argv[i], ' ') != NULL) {
            strcat(cmdline, "\"");
            strcat(cmdline, argv[i]);
            strcat(cmdline, "\"");
        } else {
            strcat(cmdline, argv[i]);
        }
    }

    // 构建环境块 (Unicode 环境块)
    // 格式: KEY=VALUE\0KEY2=VALUE2\0\0
    WCHAR *env_block = NULL;
    int env_count = 0;
    for (int i = 0; extra_envs[i] != NULL; i++) env_count++;

    if (env_count > 0) {
        size_t env_block_len = 0;
        for (int i = 0; extra_envs[i] != NULL; i++) {
            env_block_len += strlen(extra_envs[i]) * 2 + 2; // WCHAR + null
        }
        env_block_len += 2; // double null terminator
        env_block = (WCHAR *)malloc(env_block_len * sizeof(WCHAR));
        WCHAR *p = env_block;
        for (int i = 0; extra_envs[i] != NULL; i++) {
            MultiByteToWideChar(CP_UTF8, 0, extra_envs[i], -1, p, (int)(env_block_len - (p - env_block)));
            p += wcslen(p) + 1;
        }
        *p = L'\0'; // double null
    }

    // 创建管道用于捕获 stdout
    HANDLE hReadPipe, hWritePipe;
    SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
    CreatePipe(&hReadPipe, &hWritePipe, &sa, 0);

    // 设置子进程启动信息
    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = hWritePipe;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    // 转换命令行为宽字符
    WCHAR *wcmdline = (WCHAR *)malloc((strlen(cmdline) + 1) * sizeof(WCHAR));
    MultiByteToWideChar(CP_UTF8, 0, cmdline, -1, wcmdline, (int)strlen(cmdline) + 1);

    // 创建子进程
    BOOL create_ok = CreateProcessW(
        NULL, wcmdline, NULL, NULL, TRUE,
        0, env_block, NULL, &si, &pi
    );

    free(wcmdline);
    free(cmdline);
    if (env_block) free(env_block);
    free(argv);
    free(extra_envs);
    CloseHandle(hWritePipe); // 关闭写端，父进程可以读取

    if (!create_ok) {
        CloseHandle(hReadPipe);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        moonbit_bytes_t result = moonbit_make_bytes(4, 0);
        result[3] = 1; // exit_code = 1
        return result;
    }

    // 从管道读取 stdout，同时流式输出到控制台并捕获
    char read_buf[4096];
    size_t total_len = 0;
    size_t output_cap = 4096;
    char *output_buf = (char *)malloc(output_cap);

    DWORD bytes_read;
    while (ReadFile(hReadPipe, read_buf, sizeof(read_buf), &bytes_read, NULL) && bytes_read > 0) {
        // 流式输出到控制台
        DWORD written;
        WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), read_buf, bytes_read, &written, NULL);

        // 捕获到缓冲区
        if (total_len + bytes_read > output_cap) {
            output_cap = (total_len + bytes_read) * 2;
            char *new_buf = (char *)realloc(output_buf, output_cap);
            if (!new_buf) break;
            output_buf = new_buf;
        }
        memcpy(output_buf + total_len, read_buf, bytes_read);
        total_len += bytes_read;
    }
    CloseHandle(hReadPipe);

    // 等待子进程结束
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD win_exit_code;
    GetExitCodeProcess(pi.hProcess, &win_exit_code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // 构建返回结果
    int32_t result_size = 4 + total_len;
    moonbit_bytes_t result = moonbit_make_bytes(result_size, 0);
    result[0] = (win_exit_code >> 24) & 0xFF;
    result[1] = (win_exit_code >> 16) & 0xFF;
    result[2] = (win_exit_code >> 8) & 0xFF;
    result[3] = win_exit_code & 0xFF;
    if (total_len > 0) {
        memcpy((char *)result + 4, output_buf, total_len);
    }
    free(output_buf);

    return result;
}

#endif
