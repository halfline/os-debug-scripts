#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>


int main() {
    struct stat fstat_buf, stat_buf_ptmx, stat_buf_host_ptmx;
    int fd, result;

    fd = posix_openpt(O_RDWR | O_NOCTTY);
    if (fd == -1) {
        perror("posix_openpt failed");
        return EXIT_FAILURE;
    }

    if (fstat(fd, &fstat_buf) == -1) {
        perror("fstat failed");
        close(fd);
        return EXIT_FAILURE;
    }

    if (stat("/dev/pts/ptmx", &stat_buf_ptmx) == -1) {
        perror("stat on /dev/pts/ptmx failed");
        close(fd);
        return EXIT_FAILURE;
    }

    if (stat("/run/host/dev/pts/ptmx", &stat_buf_host_ptmx) == -1) {
        perror("stat on /run/host/dev/pts/ptmx failed");
        close(fd);
        return EXIT_FAILURE;
    }

    printf("Comparing st_dev and st_ino for ptm fd, /dev/pts/ptmx, and /run/host/dev/pts/ptmx:\n");
    if (fstat_buf.st_dev == stat_buf_ptmx.st_dev && fstat_buf.st_ino == stat_buf_ptmx.st_ino) {
        printf("fstat of ptm fd and stat on /dev/pts/ptmx are the same.\n");
    } else {
        printf("fstat of ptm fd and stat on /dev/pts/ptmx are different.\n");
    }

    if (fstat_buf.st_dev == stat_buf_host_ptmx.st_dev && fstat_buf.st_ino == stat_buf_host_ptmx.st_ino) {
        printf("fstat of ptm fd and stat on /run/host/dev/pts/ptmx are the same.\n");
    } else {
        printf("fstat of ptm fd and stat on /run/host/dev/pts/ptmx are different.\n");
    }

    if (stat_buf_ptmx.st_dev == stat_buf_host_ptmx.st_dev && stat_buf_ptmx.st_ino == stat_buf_host_ptmx.st_ino) {
        printf("stat on /dev/pts/ptmx and stat on /run/host/dev/pts/ptmx are the same.\n");
    } else {
        printf("stat on /dev/pts/ptmx and stat on /run/host/dev/pts/ptmx are different.\n");
    }

    close(fd);
    return 0;
}

