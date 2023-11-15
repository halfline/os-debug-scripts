#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "$0 user program [[args] ...]" >& /proc/$$/fd/2
    exit 1
fi

if [ "$(id -u)" != 0 ]; then
    echo "This program must be run as root." >& /proc/$$/fd/2
    exit 1
fi

DISPATCHER_USER="$1"
shift

VT=$(fgconsole)

xauth_file="$(mktemp)"
trap "rm -f $xauth_file" EXIT

cookie=$(mcookie)

read_display() {
   read display_number
   echo ":$display_number"
}

coproc READ_DISPLAY (read_display)
Xorg -auth "${xauth_file}" -terminate -displayfd 3 3>/proc/$$/fd/${READ_DISPLAY[1]} &
XORG_PID=$!

read -u ${READ_DISPLAY[0]} DISPLAY

chvt "$VT"
xauth -f "${xauth_file}" add "$DISPLAY" . $cookie
chown "$DISPATCHER_USER" "$xauth_file"

sudo -u "$DISPATCHER_USER" env XAUTHORITY="$xauth_file" DISPLAY="$DISPLAY" "$@"

kill -TERM $XORG_PID
