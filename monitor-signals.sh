#!/bin/bash
signal_map=(0 $(kill -L | sed -e 's/[0-9]*) //g' -e 's/SIG//g'))

outputs=("/dev/kmsg")
if [ -t 1 ]; then
   outputs+=("/dev/tty")
fi

declare -A task_map
while read -r pid command; do
    task_map["$pid"]="$command"
done < <(ps -e -o pid= -o comm=)

script_prolog=$'BEGIN {\n'

for i in "${!signal_map[@]}"; do
    script_prolog+="@signal_map[$i] = \"SIG${signal_map[$i]}\";"
    script_prolog+=$'\n';
done
for pid in "${!task_map[@]}"; do
    script_prolog+="@task_map[$pid] = \"$(echo -n ${task_map[$pid]} | sed -e 's@[\"\\]@\\&@g')\";"
    script_prolog+=$'\n';
done
script_prolog+=$'}\n'

# There's a race here where new taskes may show up before the script starts... oh well

{
    echo "$script_prolog"
    cat << '    END_OF_SCRIPT'
        tracepoint:syscalls:sys_enter_clone,
        tracepoint:syscalls:sys_exit_execve
        {
	    if (@pids_to_watch[-1] == 1 || @pids_to_watch[pid] == 1) {
                if (@task_map[pid] != "" && @task_map[pid] != comm) {
                    printf("Task %d changed names from %s to %s\n", pid, @task_map[pid], comm);
                }
	    }

            @task_map[pid] = comm;
        }

        tracepoint:sched:sched_process_free
        {
            delete(@task_map[pid]);
        }

        tracepoint:syscalls:sys_enter_kill,
        tracepoint:syscalls:sys_enter_tkill,
        tracepoint:syscalls:sys_enter_tgkill,
        tracepoint:syscalls:sys_enter_rt_sigqueueinfo,
        tracepoint:syscalls:sys_enter_rt_tgsigqueueinfo
        {
            $sender_pid = pid;

            $target_pid = (int32) args->pid;
            if ($target_pid < 0)
            {
              $whole_group = 1;
              $target_pid = -$target_pid;
            }
            else
            {
              $whole_group = 0;
            }
            $signal = args->sig;

            $sender_command = comm;
            $target_command = @task_map[$target_pid];
            $signal_name = @signal_map[$signal] != "" ? @signal_map[$signal] : str($signal);

            printf("Task %s (%d) signaled ", $sender_command, $sender_pid);
            printf("task %s (%d) ", $target_command, $target_pid);
            if ($whole_group)
            {
              printf("(and group) ");
            }
            printf("with signal %s (%d)\n", $signal_name, $signal);
            @logged_signals[$target_pid, $signal] = 1;
        }

        tracepoint:signal:signal_deliver
        {
            $target_pid = pid;
            $signal = args->sig;

            if (@logged_signals[$target_pid, $signal] == 1) {
                delete(@logged_signals[$target_pid, $signal]);
            } else {
                $target_command = @task_map[$target_pid];
                $signal_name = @signal_map[$signal] != "" ? @signal_map[$signal] : str($signal);
                printf("Kernel signaled task %s (%d) ", $target_command, $target_pid);
                printf("with signal %s (%d)\n", $signal_name, $signal);
                printf("%s\n", kstack());
            }
        }
    END_OF_SCRIPT
} | bpftrace - | tee "${outputs[@]}" > /dev/null
