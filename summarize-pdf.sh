#!/bin/bash

PDF_FILE="$1"
OUTPUT_DIR="."
INSTRUCTIONS="Please provide a detailed, unnumbered bulleted summary of this page of meeting notes in markdown. Be sure to include a heading that provides on overall summary of that page. The heading cannot have the word 'Summary' in it. It should describe content, not the headings purpose. Note, this is just one page, of many, and the summary of every page will be concatenated together, so don't assume the meeting is over when the page finishes, or that the meeting started when the page started. Be careful to not to provide inaccurate information: "

mkdir -p "$OUTPUT_DIR"

NUM_PAGES=$(pdftk "$PDF_FILE" dump_data | grep NumberOfPages | awk '{print $2}')

for PAGE in $(seq 1 $NUM_PAGES); do
    pdftk "$PDF_FILE" cat "$PAGE" output "$OUTPUT_DIR/page_$PAGE.pdf"

    pdftotext "$OUTPUT_DIR/page_$PAGE.pdf" "$OUTPUT_DIR/page_$PAGE.txt"

    PAGE_TEXT=$(cat "$OUTPUT_DIR/page_$PAGE.txt")

    echo "$INSTRUCTIONS \`\`\`$PAGE_TEXT\`\`\`" |  ollama run phi3:medium-128k | tee "$OUTPUT_DIR/summary_$PAGE.md"
done

