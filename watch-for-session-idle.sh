#!/bin/bash

shift

coproc IDLE_MONITOR (busctl --user monitor org.gnome.SessionManager)

while true
do
        # 3 means idle, it's normally 0 which means "active"
        until grep -q "3" <(busctl --user get-property org.gnome.SessionManager /org/gnome/SessionManager/Presence org.gnome.SessionManager.Presence status)
        do
                read -u "${IDLE_MONITOR[0]}"
        done

        "$@"
done

