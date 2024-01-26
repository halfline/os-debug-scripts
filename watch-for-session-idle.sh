#!/bin/bash

MATCH_FILTER="\
        type='signal',\
        interface='org.gnome.SessionManager.Presence',\
        path='/org/gnome/SessionManager/Presence'\
"

# Initialize the STATUS associative array
declare -A STATUS=(
        ['available']=0
        ['invisible']=1
        ['busy']=2
        ['idle']=3
)

restart_monitor() {
        # Kill the existing monitor process if it exists
        if [ -n "${IDLE_MONITOR_PID}" ]; then
                kill "${IDLE_MONITOR_PID}"
                wait "${IDLE_MONITOR_PID}" 2>/dev/null
        fi

        # Start or restart the monitor
        coproc IDLE_MONITOR (busctl --user monitor org.gnome.SessionManager --match "${MATCH_FILTER}" --json=short)
}

while true; do
        restart_monitor

        # Check if the user has gone idle
        until grep -q "${STATUS['idle']}" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status); do
                read -u "${IDLE_MONITOR[0]}"
                restart_monitor
        done

        # System is now idle, run command
        "$@"

        restart_monitor

        # Command run, wait for the system to become active again
        while grep -q "${STATUS['idle']}" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status); do
                read -u "${IDLE_MONITOR[0]}"
                restart_monitor
        done

        # Ensure monitor is killed at the end of the loop
        kill "${IDLE_MONITOR_PID}"
        wait "${IDLE_MONITOR_PID}" 2>/dev/null
done
