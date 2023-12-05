#!/bin/bash

mask_descriptors() {
        sed -e 's/0x[0-9a-fA-F]*\w/$pointer/g' \
            -e 's/pid [0-9]*/pid $PID/g' \
            -e 's@/proc/[0-9]*@/proc/$PID@g' \
            -e 's/fd [0-9]*/fd $FD/g' \
            $1
}

# Function to compare two files line by line
compare_files() {
        local -a result=()

        while read -r line; do
                needle=$(echo "$line" | sed -e 's/^[0-9]*:[0-9]*:[0-9]*[.][0-9]* //g')
                if ! grep -q -F -- "$needle" <(mask_descriptors "$2"); then
                        echo "${line}"
                fi
        done < <(mask_descriptors "$1")
}

# Compare $1 against $2
readarray -t FIRST_ONLY < <(compare_files "$1" "$2")

if [ ${#FIRST_ONLY[@]} -ne 0 ]; then
        echo -e "\nLines in $1 but not in $2:"
        printf "%s\n" "${FIRST_ONLY[@]}"
fi

# Compare $2 against $1
readarray -t SECOND_ONLY < <(compare_files "$2" "$1")

if [ ${#SECOND_ONLY[@]} -ne 0 ]; then
        echo -e "\nLines in $2 but not in $1:"
        printf "%s\n" "${SECOND_ONLY[@]}"
fi

