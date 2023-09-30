#!/bin/bash

declare -a signals_to_watch
declare -a pids_to_watch

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --signal)
            signal_number=$(kill -l "$2")
            [ $? -eq 0 ] && signals_to_watch+=("$signal_number")
            shift ;;
        --pid)
            pids_to_watch+=("$2")
            shift ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1 ;;
    esac
    shift
done

signal_map=(0 $(kill -L | sed -e 's/[0-9]*) //g' -e 's/SIG//g'))

animate_dots() {
    echo -en "\e[s" > /dev/tty
    while true
    do
        for byte in "." "\b \b"
        do
            for n in $(seq 1 3)
            do
                if read -t 0.1
                then
                    echo -e '\n'
                    return
                fi
                echo -en "\e[u$byte\e[s" > /dev/tty
                echo -en "\r" > /dev/tty
                echo
            done
        done
    done
}
echo -n "Loading, please wait"

outputs=("/dev/kmsg")
if [ -t 1 ]; then
   outputs+=("/dev/tty")

   coproc LOADING_ANIMATION (animate_dots)
   outputs+=("/proc/$$/fd/${LOADING_ANIMATION[1]}")
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

if [ ${#signals_to_watch[@]} -ne 0 ]; then
    for signal_number in "${signals_to_watch[@]}"; do
        script_prolog+="@signals_to_watch[$signal_number] = 1;"
        script_prolog+=$'\n';
    done
else
    script_prolog+="@signals_to_watch[-1] = 1;"
    script_prolog+=$'\n';
fi

if [ ${#pids_to_watch[@]} -ne 0 ]; then
    for pid in "${pids_to_watch[@]}"; do
        script_prolog+="@pids_to_watch[$pid] = 1;"
        script_prolog+=$'\n';
    done
else
    script_prolog+="@pids_to_watch[-1] = 1;"
    script_prolog+=$'\n';
fi

script_prolog+='printf("Monitoring signals.\n");'
script_prolog+=$'\n'

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
            if ($target_pid < 0) {
                $whole_group = 1;
                $target_pid = -$target_pid;
            } else {
                $whole_group = 0;
            }
            $signal = args->sig;

            if ((@pids_to_watch[-1] == 1 || @pids_to_watch[$target_pid] == 1) &&
                (@signals_to_watch[-1] == 1 || @signals_to_watch[$signal] == 1)) {
                $sender_command = comm;
                $target_command = @task_map[$target_pid];
                $signal_name = @signal_map[$signal] != "" ? @signal_map[$signal] : str($signal);

                printf("Task %s (%d) signaled ", $sender_command, $sender_pid);
                printf("task %s (%d) ", $target_command, $target_pid);
                if ($whole_group) {
                    printf("(and group) ");
                }
                printf("with signal %s (%d)\n", $signal_name, $signal);
                @logged_signals[$target_pid, $signal] = 1;
            }
        }

        tracepoint:signal:signal_generate
        {
            $target_pid = pid;
            $signal = args->sig;

            if (@logged_signals[$target_pid, $signal] == 1) {
                delete(@logged_signals[$target_pid, $signal]);
            } else if ((@pids_to_watch[-1] == 1 || @pids_to_watch[$target_pid] == 1) &&
                       (@signals_to_watch[-1] == 1 || @signals_to_watch[$signal] == 1)) {
                $target_command = @task_map[$target_pid];
                $signal_name = @signal_map[$signal] != "" ? @signal_map[$signal] : str($signal);
                printf("Kernel signaled task %s (%d) ", $target_command, $target_pid);
                printf("with signal %s (%d)\n", $signal_name, $signal);
                printf("%s\n", kstack());
            }
        }
    END_OF_SCRIPT
} | bpftrace - | strings | tee -p "${outputs[@]}" > /dev/null
