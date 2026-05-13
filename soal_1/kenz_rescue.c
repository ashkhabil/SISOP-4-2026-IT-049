#define FUSE_USE_VERSION 28
#define _FILE_OFFSET_BITS 64
#define _DEFAULT_SOURCE

#include <fuse.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <stdlib.h>

static const char *dirpath = "/home/adduser/sisop/praktikum/amba_files";
static const char *virtual_file = "/tujuan.txt";


/* generate isi tujuan.txt */
static char *generate_tujuan() {
    static char result[4096];
    result[0] = '\0';

    strcat(result, "Tujuan Mas Amba: ");

    for (int i = 1; i <= 7; i++) {
        char filepath[256];
        snprintf(filepath, sizeof(filepath), "%s/%d.txt", dirpath, i);

        FILE *fp = fopen(filepath, "r");
        if (!fp) continue;

        char line[1024];
        while (fgets(line, sizeof(line), fp)) {
            char *start = strstr(line, "KOORD: ");
            if (start) {
                start += strlen("KOORD: ");

                /* hapus newline */
                char *newline = strchr(start, '\n');
                if (newline) *newline = '\0';

                strcat(result, start);
                break;  // cukup 1 KOORD per file
            }
        }

        fclose(fp);
    }

    strcat(result, "\n");
    return result;
}


/* getattr */
static int xmp_getattr(const char *path, struct stat *stbuf) {
    int res;
    char fpath[1000];

    memset(stbuf, 0, sizeof(struct stat));

    /* virtual file */
    if (strcmp(path, virtual_file) == 0) {
        char *content = generate_tujuan();

        stbuf->st_mode = S_IFREG | 0444;
        stbuf->st_nlink = 1;
        stbuf->st_size = strlen(content);
        return 0;
    }

    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    res = lstat(fpath, stbuf);
    if (res == -1) return -errno;

    return 0;
}


/* readdir */
static int xmp_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                       off_t offset, struct fuse_file_info *fi) {
    char fpath[1000];

    if (strcmp(path, "/") == 0)
        snprintf(fpath, sizeof(fpath), "%s", dirpath);
    else
        snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    DIR *dp;
    struct dirent *de;

    (void) offset;
    (void) fi;

    dp = opendir(fpath);
    if (dp == NULL) return -errno;

    while ((de = readdir(dp)) != NULL) {
        struct stat st;
        memset(&st, 0, sizeof(st));

        st.st_ino = de->d_ino;
        st.st_mode = de->d_type << 12;

        if (filler(buf, de->d_name, &st, 0))
            break;
    }

    /* tambahkan file virtual */
    filler(buf, "tujuan.txt", NULL, 0);

    closedir(dp);
    return 0;
}


/* open */
static int xmp_open(const char *path, struct fuse_file_info *fi) {
    char fpath[1000];
    int res;

    if (strcmp(path, virtual_file) == 0)
        return 0;

    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    res = open(fpath, fi->flags);
    if (res == -1) return -errno;

    close(res);
    return 0;
}


/* read */
static int xmp_read(const char *path, char *buf, size_t size,
                    off_t offset, struct fuse_file_info *fi) {

    /* virtual file */
    if (strcmp(path, virtual_file) == 0) {
        char *content = generate_tujuan();
        size_t len = strlen(content);

        if (offset < len) {
            if (offset + size > len)
                size = len - offset;

            memcpy(buf, content + offset, size);
        } else {
            size = 0;
        }

        return size;
    }

    char fpath[1000];
    snprintf(fpath, sizeof(fpath), "%s%s", dirpath, path);

    int fd;
    int res;

    (void) fi;

    fd = open(fpath, O_RDONLY);
    if (fd == -1) return -errno;

    res = pread(fd, buf, size, offset);
    if (res == -1) res = -errno;

    close(fd);
    return res;
}


/* operations */
static struct fuse_operations xmp_oper = {
    .getattr = xmp_getattr,
    .readdir = xmp_readdir,
    .open    = xmp_open,
    .read    = xmp_read,
};


int main(int argc, char *argv[]) {
    umask(0);
    return fuse_main(argc, argv, &xmp_oper, NULL);
}