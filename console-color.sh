#!/bin/bash
#
# conserver seems to have strip out control characters leaving a mess in the output
#
# This just puts back the color ones

restore_ansi_sequences() {
    sed -e 's/\[\([0-9;]*m\)/\x1b[\1/g'
}

console "$@" 2>&1 | restore_ansi_sequences

