#!/bin/bash

DAYS=${1:-7}

OBJECT_DIR=".git/objects"

recent_objects=$(find $OBJECT_DIR -type f -mtime -$DAYS)
get_commits_in_range() {
    for obj_path in $recent_objects; do
        obj_hash=$(echo $obj_path | sed -e 's@.*objects/@@' -e 's@/@@')
        object_type=$(git cat-file -t $obj_hash 2> /dev/null)
        if [ "$object_type" = "commit" ]; then
            echo $obj_hash
        fi
    done
}

COMMITS=$(get_commits_in_range)
echo "$COMMITS"

