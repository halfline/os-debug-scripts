#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "$0 mins program [[args] ...]" >& /proc/$$/fd/2
    exit 1
fi

IDLE_TIME_US=$(($1 * 60 * 1000000))
shift

while true
do
    shortest_idle_time=$((IDLE_TIME_US + 1))
    sessions=($(busctl --list tree org.freedesktop.login1 | grep session/ | grep -E -v 'auto|self'))
    for session in "${sessions[@]}"; do
        session_type=$(busctl get-property org.freedesktop.login1 $session org.freedesktop.login1.Session Type | awk '{print $2}' | awk -F'"' '{print $2}')

        if [ "$session_type" != "x11" -a "$session_type" != "wayland" ]; then
            continue
        fi

        idle_hint=$(busctl get-property org.freedesktop.login1 $session org.freedesktop.login1.Session IdleHint | awk '{print $2}')
        if [ "$idle_hint" = "false" ]; then
            shortest_idle_time=0
            continue
        fi

        idle_since_hint=$(busctl get-property org.freedesktop.login1 $session org.freedesktop.login1.Session IdleSinceHint | awk '{print $2}')

        current_time=$(date +%s%6N)
        idle_time=$((current_time - idle_since_hint))

        if [ "$idle_time" -lt "$shortest_idle_time" ]; then
            shortest_idle_time=$idle_time
        fi
    done

    if [ "${shortest_idle_time}" -gt 0 ]; then
        time_left=$(((IDLE_TIME_US - shortest_idle_time) / 1000000))

        if [ "$time_left" -le 0 ]; then
            break
        fi
    fi

    sleep $((${time_left} + 1))
done

echo "Session now idle for $((shortest_idle_time / 1000000 / 60)) minutes, running command"
"$@"
