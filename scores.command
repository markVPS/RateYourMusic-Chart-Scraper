#!/bin/bash

# Pull content from clipboard
clipboard_content=$(pbpaste)

# Extract the second line for the name
#name=$(echo "$clipboard_content" | awk 'NR == 2' | sed 's/[^[:alpha:] .]//g' | sed 's/^ //')
name=$(echo "$clipboard_content" | awk 'NR == 2' | sed "s/[^[:alpha:] .&':!]//g" | sed 's/^ //')

# Set default output file
output_file="director_list.tsv"

# Check for exact match lines, stopping at the first match
if echo "$clipboard_content" | grep -m 1 -x "Game Company" > /dev/null; then
    output_file="company_list.tsv"
elif echo "$clipboard_content" | grep -m 1 -x "Franchise" > /dev/null; then
    output_file="franchise_list.tsv"
fi

# Process the clipboard content
echo "$clipboard_content" | awk -v name="$name" -v output_file="$output_file" '
    BEGIN {
        total_score = 0
        total_reviews = 0
        multiplier_next = 0
    }
    {
        if ($0 == "Other Roles") {
            exit
        }

        gsub(/^[ \t]+|[ \t]+$/, "", $0)

        if ($0 ~ /^[[:space:]]*[0-9]+\.[0-9][0-9]?$/) {
            rating = $0
            gsub(/[[:space:]]/, "", rating)
            multiplier_next = 1
        } else if (multiplier_next) {
            count = $0
            gsub(/,/, "", count)
            if (count ~ /^[0-9]+$/) {
                score = rating * count
                total_score += score
                total_reviews += count
            }
            multiplier_next = 0
        }
    }
    END {
        if (total_reviews > 0) {
            avg = total_score / total_reviews
            printf("%s\t%d\t%.5f\n", name, total_reviews, avg) >> output_file
        } else {
            print("No valid reviews found.")
        }
    }
'
