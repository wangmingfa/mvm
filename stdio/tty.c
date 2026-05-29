// tty.c

// #include <stdio.h>

#ifdef _WIN32
#include <io.h>
#else
#include <unistd.h>
#endif

// stdin 是否是 tty
int is_stdin_tty() {
#ifdef _WIN32
    return _isatty(_fileno(stdin));
#else
    return isatty(STDIN_FILENO);
#endif
}

// stdout 是否是 tty
int is_stdout_tty() {
#ifdef _WIN32
    return _isatty(_fileno(stdout));
#else
    return isatty(STDOUT_FILENO);
#endif
}

// stderr 是否是 tty
int is_stderr_tty() {
#ifdef _WIN32
    return _isatty(_fileno(stderr));
#else
    return isatty(STDERR_FILENO);
#endif
}

// int main() {

//     printf("stdin  tty: %d\n", is_stdin_tty());
//     printf("stdout tty: %d\n", is_stdout_tty());
//     printf("stderr tty: %d\n", is_stderr_tty());

//     return 0;
// }