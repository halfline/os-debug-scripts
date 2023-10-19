#!/bin/bash

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --all)
            exec pw-cli list-objects | grep -v '=' | grep id |awk '{ print $2 }' | awk -F, '{ print $1 }' | xargs -P0  -IID "$0" --id ID
            ;;
        --id)
            id="$2"
            shift ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1 ;;
    esac
    shift
done

if [ -t 1 ]; then
    outputs=("/dev/tty")
fi

watch_for_preroll() {
    TIMEOUT=10
    while IFS= read -r -t $TIMEOUT line; do
        echo "$line"
        if [[ $line == *"Pipeline is PREROLLED"* ]]; then
            echo "$id: Pipeline prerolled!"
            return
        fi
    done
    exit 1
}
coproc SCREEN_SCRAPER (watch_for_preroll)

if [ -z "${SCREEN_SCRAPER_PID}" ]; then
    exit 1
fi
trap "kill ${SCREEN_SCRAPER_PID} >& /dev/null" EXIT

outputs+=("/proc/$$/fd/${SCREEN_SCRAPER[1]}")

gst-launch-1.0 pipewiresrc path=$id ! videoconvert ! autovideosink |&grep -v PAUSED |& grep -v attached | sed "s/^/$id: /" |& tee -p "${outputs[@]}" > /dev/null
