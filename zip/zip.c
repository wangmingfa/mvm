#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "miniz.h"

#ifdef _WIN32
#include <direct.h>
#define MKDIR(path) _mkdir(path)
#else
#include <sys/stat.h>
#define MKDIR(path) mkdir(path, 0755)
#endif

typedef struct {
    FILE *fp;
    uint64_t written;
    uint64_t total;
} extract_ctx_t;

static size_t write_callback(void *pOpaque, mz_uint64 file_ofs,
                              const void *pBuf, size_t n) {
    extract_ctx_t *ctx = (extract_ctx_t *)pOpaque;

    (void)file_ofs;

    size_t written = fwrite(pBuf, 1, n, ctx->fp);
    ctx->written += written;

    return written;
}

static void create_parent_dirs(const char *path) {
    char tmp[1024];
    strncpy(tmp, path, sizeof(tmp) - 1);
    tmp[sizeof(tmp) - 1] = '\0';

    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/' || *p == '\\') {
            char c = *p;
            *p = '\0';
            MKDIR(tmp);
            *p = c;
        }
    }
}

int unzip_to_dir_with_progress(
    const char *zip_path,
    const char *out_dir,
    void (*progress)(void* user_data, float percent),
    void *user_data
) {
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));

    if (!mz_zip_reader_init_file(&zip, zip_path, 0)) {
        return -1;
    }

    mz_uint num_files = mz_zip_reader_get_num_files(&zip);

    // 先统计总大小（用于进度）
    uint64_t total_size = 0;
    for (mz_uint i = 0; i < num_files; i++) {
        mz_zip_archive_file_stat st;
        if (mz_zip_reader_file_stat(&zip, i, &st) &&
            !mz_zip_reader_is_file_a_directory(&zip, i)) {
            total_size += st.m_uncomp_size;
        }
    }

    uint64_t done = 0;

    for (mz_uint i = 0; i < num_files; i++) {
        mz_zip_archive_file_stat st;

        if (!mz_zip_reader_file_stat(&zip, i, &st))
            continue;

        char out_path[2048];
        snprintf(out_path, sizeof(out_path),
                 "%s/%s", out_dir, st.m_filename);

        if (mz_zip_reader_is_file_a_directory(&zip, i)) {
            MKDIR(out_path);
            continue;
        }

        create_parent_dirs(out_path);

        FILE *fp = fopen(out_path, "wb");
        if (!fp) {
            mz_zip_reader_end(&zip);
            return -2;
        }

        extract_ctx_t ctx = {
            .fp = fp,
            .written = 0,
            .total = st.m_uncomp_size
        };

        int ok = mz_zip_reader_extract_to_callback(
            &zip,
            i,
            write_callback,
            &ctx,
            0
        );

        fclose(fp);

        if (!ok) {
            mz_zip_reader_end(&zip);
            return -3;
        }

        done += st.m_uncomp_size;

        if (progress && total_size > 0) {
            // 进度：0 - 100
            float percent_val = (float)done  * 100.0f / total_size;
            progress(user_data, percent_val);
        }
    }

    mz_zip_reader_end(&zip);
    return 0;
}
