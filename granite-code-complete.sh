#!/bin/sh

prefix="$1"
suffix="$2"
input=$(mktemp)
cat > "$input" << EOF
/set parameter temperature 0
/set parameter seed 0
/set parameter num_ctx CONTEXT_WINDOW_SIZE
/set parameter num_predict 64
/set nohistory
/set system """
You are a helpful and precise assistant specializing in completing code snippets. Your task is to fill in missing sections of code while preserving the surrounding context and ensuring the code is syntactically correct and semantically coherent. You are provided with:

    Prefix: The code leading up to the missing section.
    Suffix: The code following the missing section.

Your output must logically connect the prefix and suffix while adhering to best practices, the specified programming language, and style guidelines. Always aim for concise, efficient, and readable code.
Guidelines:

 - Provide the fully completed code, including the prefix, completed section and suffix in the output
 - Generate code that matches the overall style of the prefix and suffix.
 - Do not explain the completion, just give the raw results.
 - If multiple solutions are plausible, choose the simplest and most commonly accepted approach.
 - Do not assume functions are available unless they have been mentioned or are part of standard libraries.

Example:

Prefix:
\`\`\`c
int sum(int a, int b) {
    return
\`\`\`

Suffix:
\`\`\`c
;
}
\`\`\`

Completed code segment:
\`\`\`c
int sum(int a, int b) {
    return a + b;
}
\`\`\`
"""

What is the expected completion for this code:

Prefix:
\`\`\`c
$prefix
\`\`\`

Suffix:
\`\`\`c
$suffix
\`\`\`

Completed code segment:
EOF

NUM_BYTES=$(wc -c "$input" | awk '{ print $1 }')
NUM_TOKENS=$(( NUM_BYTES / 4))

output=$(mktemp)
sed "s/CONTEXT_WINDOW_SIZE/$NUM_TOKENS/" "$input" | ollama run granite3-dense:8b > "$output"

code=$(cat "$output")
code=${code#"\`\`\`c"}
code=${code%"\`\`\`"}
code=${code#"$prefix"}
code=${code%"$suffix"}

echo -ne "$prefix\e[1;31m$code\e[0m$suffix"

