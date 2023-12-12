#!/usr/bin/env bpftrace

BEGIN
{
    printf("Tracing common NSS calls... Hit Ctrl-C to end.\n");
}

uprobe:/lib64/libc.so.6:getpwnam_r
{
    printf("%-8s %-6d getpwnam(%s)\n", comm, pid, str(arg0));
}

uretprobe:/lib64/libc.so.6:getpwnam_r
/retval != 0/
{
    printf("%-8s %-6d getpwnam failed\n", comm, pid);
}

uprobe:/lib64/libc.so.6:getpwuid_r
{
    printf("%-8s %-6d getpwuid(%d)\n", comm, pid, arg0);
}

uretprobe:/lib64/libc.so.6:getpwuid_r
/retval != 0/
{
    printf("%-8s %-6d getpwuid failed\n", comm, pid);
}

uprobe:/lib64/libc.so.6:getgrnam_r
{
    printf("%-8s %-6d getgrnam(%s)\n", comm, pid, str(arg0));
}

uretprobe:/lib64/libc.so.6:getgrnam_r
/retval != 0/
{
    printf("%-8s %-6d getgrnam failed\n", comm, pid);
}

uprobe:/lib64/libc.so.6:getgrgid_r
{
    printf("%-8s %-6d getgrgid(%d)\n", comm, pid, arg0);
}

uretprobe:/lib64/libc.so.6:getgrgid_r
/retval != 0/
{
    printf("%-8s %-6d getgrgid failed\n", comm, pid);
}

