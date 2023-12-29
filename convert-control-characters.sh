#!/bin/bash

input_string="$1"
output_string=""
i=0

while [ $i -lt ${#input_string} ]
do
        character=${input_string:$i:1}

        if [[ "$character" == "^" && $((i+1)) -lt ${#input_string} ]]
        then
                ((i++))
                next_character=${input_string:${i}:1}
                ascii_value=$(printf "%d" "'$next_character")
                control_code=$((ascii_value - 64))

                output_string+="\\$(printf '%03o' "$control_code")"
        else
                output_string+="$character"
        fi
        ((i++))
done

echo -ne "$output_string"
