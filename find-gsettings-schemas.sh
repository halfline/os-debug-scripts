#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <URL>"
    exit 1
fi

URL="$1"

if ! command -v lynx &> /dev/null; then
    echo "lynx could not be found. Please install it to run this script."
    exit 1
fi

TEXT_FILE="$(mktemp)"
DCONF_KEYS_FILE="$(mktemp)"
SCHEMA_KEYS_FILE="$(mktemp)"

lynx -dump -nolist "$URL" > "$TEXT_FILE"

NON_DCONF_PATHS="etc|usr|var|home|tmp|bin|sbin|lib|opt|run|sys|proc|dev|mnt|media|srv|boot|root|daemon|xdmcp|debug"

CURRENT_SECTION=""
> "$DCONF_KEYS_FILE"

while IFS= read -r LINE; do
    LINE="$(echo "$LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    [ -z "$LINE" ] && continue

    if echo "$LINE" | grep -qP '^\[.*\]$'; then
        SECTION_NAME="$(echo "$LINE" | sed -n 's/^\[\(.*\)\]$/\1/p')"
        if [[ "$SECTION_NAME" != /* ]]; then
            SECTION_NAME="/$SECTION_NAME"
        fi
        if echo "$SECTION_NAME" | grep -qP "^/($NON_DCONF_PATHS)(/|$)"; then
            CURRENT_SECTION=""
        else
            CURRENT_SECTION="$SECTION_NAME"
        fi
    elif [[ "$CURRENT_SECTION" != "" ]]; then
        if echo "$LINE" | grep -qP '^[a-zA-Z0-9_-]+\s*='; then
            KEY_NAME="$(echo "$LINE" | sed -n 's/^\([a-zA-Z0-9_-]\+\)\s*=.*/\1/p')"
            FULL_KEY="$CURRENT_SECTION/$KEY_NAME"
            echo "$FULL_KEY" >> "$DCONF_KEYS_FILE"
        fi
    else
        if echo "$LINE" | grep -qP '(?<=^|\s|")/(?!(('"$NON_DCONF_PATHS"')/))([a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)+)'; then
            MATCHES=$(echo "$LINE" | grep -oP '(?<=^|\s|")/(?!(('"$NON_DCONF_PATHS"')/))([a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)+)')
            for MATCH in $MATCHES; do
                echo "$MATCH" >> "$DCONF_KEYS_FILE"
            done
        fi
    fi
done < "$TEXT_FILE"

sort -u "$DCONF_KEYS_FILE" -o "$DCONF_KEYS_FILE"

> "$SCHEMA_KEYS_FILE"

for SCHEMA_FILE in /usr/share/glib-2.0/schemas/*.xml; do
    IN_SCHEMA=0
    SCHEMA_PATH=""
    while IFS= read -r LINE; do
        if echo "$LINE" | grep -q '<schema'; then
            SCHEMA_PATH=$(echo "$LINE" | sed -n 's/.*path="\([^"]*\)".*/\1/p')
            [ -z "$SCHEMA_PATH" ] && SCHEMA_PATH="/"
            IN_SCHEMA=1
            continue
        fi

        if echo "$LINE" | grep -q '</schema>'; then
            IN_SCHEMA=0
            SCHEMA_PATH=""
            continue
        fi

        if [ "$IN_SCHEMA" = "1" ]; then
            if echo "$LINE" | grep -q '<key'; then
                KEY_NAME=$(echo "$LINE" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
                echo -e "${SCHEMA_PATH}\t${KEY_NAME}" >> "$SCHEMA_KEYS_FILE"
            fi
        fi
    done < "$SCHEMA_FILE"
done

while read -r DCONF_KEY; do
    DCONF_KEY="$(echo "$DCONF_KEY" | sed 's|//|/|g')"

    DCONF_PATH="$(echo "$DCONF_KEY" | sed -E 's|(.*/)[^/]+$|\1|')"
    KEY_NAME="$(echo "$DCONF_KEY" | awk -F'/' '{print $NF}')"

    if grep -q "^${DCONF_PATH}[[:space:]]${KEY_NAME}$" "$SCHEMA_KEYS_FILE"; then
        echo "Key '$DCONF_KEY' is associated with an installed schema."
    else
        echo "Key '$DCONF_KEY' is NOT associated with any installed schema."
    fi
done < "$DCONF_KEYS_FILE"

rm "$TEXT_FILE" "$DCONF_KEYS_FILE" "$SCHEMA_KEYS_FILE"

