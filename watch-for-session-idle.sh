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

# Monitor session manager presence status changes announced over the bus in another process running alongside this one
coproc IDLE_MONITOR (busctl --user monitor org.gnome.SessionManager --match "${MATCH_FILTER}" --json=short)

while true
do
        # Check if the user has gone idle
        until grep -q "${STATUS['idle']}" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status)
        do
                # If not, wait idly until the other process reports more bus traffic from the session manager
                read -u "${IDLE_MONITOR[0]}"
        done

        # System is now idle, run command
        "$@"

        # Command run, wait for the system to become active again
        while grep -q "${STATUS['idle']}" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status)
        do
                # If not active, wait idly until the other process reports more bus traffic from the session manager
                read -u "${IDLE_MONITOR[0]}"
        done

        # System is now active, loop and block until idle again
done

