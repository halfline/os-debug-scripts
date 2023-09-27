#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <time.h>
#include <signal.h>

int
main()
{
    struct rlimit rlim;
    struct sched_param sched_param;
    struct timespec start, end;
    long elapsed_ms;
    int ret;

    rlim.rlim_cur = rlim.rlim_max = 50 * 1000;
    ret = setrlimit(RLIMIT_RTTIME, &rlim);
    if (ret < 0) {
        perror("setrlimit");
        exit(1);
    }

    sched_param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    ret = sched_setscheduler(0, SCHED_FIFO, &sched_param);
    if (ret < 0) {
        perror("sched_setscheduler");
        exit(1);
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    while (1) {
        clock_gettime(CLOCK_MONOTONIC, &end);
        elapsed_ms = (end.tv_sec - start.tv_sec) * 1000;
        elapsed_ms += (end.tv_nsec - start.tv_nsec) / 1000000;
        if (elapsed_ms >= 100) {
            break;
        }
    }

    return 0;
}
