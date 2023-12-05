#!/bin/bash

# Monitor all session manager bus traffic in another process running alongside this one
coproc IDLE_MONITOR (busctl --user monitor org.gnome.SessionManager)

while true
do
        # Check if the user has gone idle
        # 3 means idle, it's normally 0 which means "active"
        until grep -q "3" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status)
        do
                # If not, wait idly until the other process reports more bus traffic from the session manager
                read -u "${IDLE_MONITOR[0]}"
        done

        # System is now idle, run command
        "$@"

        # Command run, wait for the system to become active again
        until grep -q "0" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status)
        do
                # If not active, wait idly until the other process reports more bus traffic from the session manager
                read -u "${IDLE_MONITOR[0]}"
        done

        # System is now active, loop and block until idle again
done

