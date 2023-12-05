#!/bin/bash

# Compare $1 against $2
readarray -t FIRST_ONLY < <(grep -v -F -f <(sed -e 's/^[0-9]*:[0-9]*:[0-9]* //g' -e 's/0x[0-9a-f]*\w/$pointer/g' -e 's/[0-9]/N/g' $2) -- <(sed -e 's/0x[0-9a-f]*\w/$pointer/g' -e 's/[0-9]/N/g' $1))

# Compare $2 against $1
readarray -t SECOND_ONLY < <(grep -v -F -f <(sed -e 's/^[0-9]*:[0-9]*:[0-9]* //g' -e 's/0x[0-9a-f]*\w/$pointer/g' -e 's/[0-9]/N/g' $1) -- <(sed -e 's/0x[0-9a-f]*\w/$pointer/g' -e 's/[0-9]/N/g' $2))

# Print results if arrays are not empty
if [ ${#FIRST_ONLY[@]} -ne 0 ]; then
        echo "Lines in $1 but not in $2:"
        printf "%s\n" "${FIRST_ONLY[@]}"
fi

if [ ${#SECOND_ONLY[@]} -ne 0 ]; then
        echo -e "\nLines in $2 but not in $1:"
        printf "%s\n" "${SECOND_ONLY[@]}"
fi

