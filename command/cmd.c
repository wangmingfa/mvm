#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"
#include "../ffi/string.c"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/wait.h>
extern char **environ;
#endif

/* ============================================================
 * Callback
 * ============================================================ */

typedef void (*command_callback)(
    int exit_code,
    moonbit_string_t output,
    void *user_data
);

/* ============================================================
 * String Builder
 * ============================================================ */

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} StringBuilder;

static void sb_init(StringBuilder *sb)
{
    sb->cap = 4096;
    sb->len = 0;
    sb->data = (char *)malloc(sb->cap);
    sb->data[0] = '\0';
}

static void sb_append(StringBuilder *sb, const char *buf, size_t n)
{
    if (sb->len + n + 1 > sb->cap) {
        while (sb->len + n + 1 > sb->cap)
            sb->cap *= 2;

        sb->data = (char *)realloc(sb->data, sb->cap);
    }

    memcpy(sb->data + sb->len, buf, n);

    sb->len += n;
    sb->data[sb->len] = '\0';
}

/* ============================================================
 * ENV Parsing
 *
 * KEY=VALUE&KEY2=VALUE2
 * ============================================================ */

static int count_envs(const char *envs)
{
    if (!envs || !*envs)
        return 0;

    int count = 1;

    while (*envs) {
        if (*envs == '&')
            count++;
        envs++;
    }

    return count;
}

#ifndef _WIN32

/* ============================================================
 * Linux/macOS env builder
 * ============================================================ */

static char **build_envp(const char *extra_envs)
{
    int base_count = 0;

    while (environ[base_count])
        base_count++;

    int extra_count = count_envs(extra_envs);

    char **envp =
        (char **)malloc(
            sizeof(char *) *
            (base_count + extra_count + 1));

    int idx = 0;

    for (int i = 0; i < base_count; i++) {
        envp[idx++] = environ[i];
    }

    if (extra_envs && *extra_envs) {

        char *copy = strdup(extra_envs);

        char *token = strtok(copy, "&");

        while (token) {
            envp[idx++] = strdup(token);
            token = strtok(NULL, "&");
        }

        free(copy);
    }

    envp[idx] = NULL;

    return envp;
}

#endif

#ifdef _WIN32

/* ============================================================
 * Windows env block
 *
 * KEY=VALUE\0KEY2=VALUE2\0\0
 * ============================================================ */

static char *build_windows_env_block(const char *envs)
{
    if (!envs || !*envs)
        return NULL;

    size_t len = strlen(envs);

    char *block = (char *)malloc(len + 2);

    size_t j = 0;

    for (size_t i = 0; i < len; i++) {
        if (envs[i] == '&')
            block[j++] = '\0';
        else
            block[j++] = envs[i];
    }

    block[j++] = '\0';
    block[j++] = '\0';

    return block;
}

#endif

/* ============================================================
 * Main API
 * ============================================================ */

void run_command(
    const char *cmd,
    const char *cwd,
    const char *envs,
    command_callback cb,
    void *user_data
)
{
#ifdef _WIN32

    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(sa);
    sa.lpSecurityDescriptor = NULL;
    sa.bInheritHandle = TRUE;

    HANDLE read_pipe;
    HANDLE write_pipe;

    CreatePipe(
        &read_pipe,
        &write_pipe,
        &sa,
        0
    );

    SetHandleInformation(
        read_pipe,
        HANDLE_FLAG_INHERIT,
        0
    );

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    ZeroMemory(&pi, sizeof(pi));

    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = write_pipe;
    si.hStdError = write_pipe;

    char *cmdline = _strdup(cmd);

    const char *real_cwd =
        (cwd && cwd[0] != '\0')
            ? cwd
            : NULL;

    char *env_block =
        build_windows_env_block(envs);

    BOOL ok = CreateProcessA(
        NULL,
        cmdline,
        NULL,
        NULL,
        TRUE,
        0,
        env_block,
        real_cwd,
        &si,
        &pi
    );

    free(cmdline);

    if (env_block)
        free(env_block);

    CloseHandle(write_pipe);

    if (!ok) {
        CloseHandle(read_pipe);

        if (cb)
            cb(-1,
               make_moonbit_str("CreateProcess failed"),
               user_data);

        return;
    }

    StringBuilder sb;
    sb_init(&sb);

    char buf[4096];
    DWORD n;

    while (ReadFile(
               read_pipe,
               buf,
               sizeof(buf),
               &n,
               NULL) &&
           n > 0)
    {
        fwrite(buf, 1, n, stdout);
        fflush(stdout);

        sb_append(&sb, buf, n);
    }

    WaitForSingleObject(
        pi.hProcess,
        INFINITE
    );

    DWORD exit_code = 0;

    GetExitCodeProcess(
        pi.hProcess,
        &exit_code
    );

    if (cb) {
        cb(
            (int)exit_code,
            make_moonbit_str(sb.data),
            user_data
        );
    }

    free(sb.data);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    CloseHandle(read_pipe);

#else

    int pipefd[2];

    if (pipe(pipefd) != 0) {
        if (cb)
            cb(-1,
               make_moonbit_str("pipe failed"),
               user_data);
        return;
    }

    pid_t pid = fork();

    if (pid == 0) {

        if (cwd && cwd[0] != '\0') {
            chdir(cwd);
        }

        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);

        close(pipefd[0]);
        close(pipefd[1]);

        char **envp =
            build_envp(envs);

        execle(
            "/bin/sh",
            "sh",
            "-c",
            cmd,
            NULL,
            envp
        );

        _exit(127);
    }

    close(pipefd[1]);

    StringBuilder sb;
    sb_init(&sb);

    char buf[4096];
    ssize_t n;

    while ((n = read(
                pipefd[0],
                buf,
                sizeof(buf))) > 0)
    {
        fwrite(buf, 1, n, stdout);
        fflush(stdout);

        sb_append(&sb, buf, (size_t)n);
    }

    close(pipefd[0]);

    int status = 0;

    waitpid(
        pid,
        &status,
        0
    );

    int exit_code = -1;

    if (WIFEXITED(status))
        exit_code = WEXITSTATUS(status);
    else if (WIFSIGNALED(status))
        exit_code = 128 + WTERMSIG(status);

    if (cb) {
        cb(
            exit_code,
            make_moonbit_str(sb.data),
            user_data
        );
    }

    free(sb.data);

#endif
}

void print(const char* s) {
    printf("%s", s);
}