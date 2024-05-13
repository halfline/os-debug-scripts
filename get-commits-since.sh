#!/bin/bash

DAYS=${1:-7}

now_timestamp=$(date +%s)
start_timestamp=$(($now_timestamp - $DAYS * 24 * 60 * 60))

get_commits_in_range() {
    git reflog --date=unix | while read -r line; do
        timestamp=$(echo "$line" | sed -n 's/.*HEAD@{\([0-9]*\)}.*/\1/p')
        commit=$(echo "$line" | sed -n 's/^\([0-9a-f]*\) .*/\1/p')
        if [ "$timestamp" -ge "$start_timestamp" ]; then
            echo "$commit"
        fi
    done
}

COMMITS=$(get_commits_in_range | uniq)

echo "$COMMITS"
