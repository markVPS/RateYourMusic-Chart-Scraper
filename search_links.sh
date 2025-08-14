#!/bin/bash

tsv="media_and_soundtrack.tsv"
temp_file=$(mktemp)

# URL-encode function
urlencode() {
  local str="$1"
  local encoded=""
  local i c
  for (( i = 0; i < ${#str}; i++ )); do
    c=${str:$i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *) printf -v encoded "%s%%%02X" "$encoded" "'$c"
    esac
  done
  echo "$encoded"
}

# Print header to temp file
head -n 1 "$tsv" >> "$temp_file"

# Process each row
while IFS=$'\t' read -r col1 col2 col3 col4 col5; do
  echo
  echo "🔍 Searching: $col1"

  trimmed_col1=$(echo "$col1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  query="site:rateyourmusic.com/film/ \"$trimmed_col1\" \"/ 5.0\" -ai"
  encoded_query=$(urlencode "$query")
  search_url="https://www.google.com/search?q=$encoded_query"
done < <(tail -n +2 "$tsv")

  # Use AppleScript to load URL into Firefox in the current tab
  osascript <<EOF
tell application "Firefox"
  activate
end tell
delay 1
tell application "System Events"
  keystroke "l" using {command down}
  delay 0.2
  keystroke "$search_url"
  delay 0.2
  key code 36 -- press Return
  delay 2
  keystroke "a" using {command down}
  delay 2
  keystroke "c" using {command down}
end tell
EOF

  # Read and clean clipboard
  sleep 1
  clipboard=$(pbpaste)

  # Extract relevant lines
  matches=""
  while IFS= read -r line; do
    if [[ "$line" == *" ratings."* ]]; then
      # Keep everything up to and including ' ratings.'; remove what follows
      line=$(echo "$line" | awk '{match($0, / ratings\./); if (RSTART) print substr($0, 1, RSTART+RLENGTH-1); else print $0}')

    fi
    # Append line if not empty
    if [[ -n "$line" ]]; then
      matches+="$line"$'\n'
    fi
  done < <(echo "$clipboard" | grep -E '[0-9]+(\.[0-9]+)? ?/ ?5\.0.*from [0-9,]+ ratings')


  i=1
  choices=()
  while IFS= read -r line; do
    title=$(echo "$line" | cut -d';' -f1 | sed 's/^[[:space:]]*//')

    # Extract rating (allow formats like 4.32 / 5.0 or 4 / 5.0)
    rating=$(echo "$line" | grep -Eo '[0-5](\.[0-9]+)? / 5\.0' | head -n1 | grep -Eo '[0-5](\.[0-9]+)?')

    # Extract votes and strip commas
    votes=$(echo "$line" | grep -Eo '[0-9,]+[[:space:]]*ratings' | grep -Eo '[0-9,]+' | tail -n1 | tr -d ',')


    if [[ -n "$title" && -n "$rating" && -n "$votes" ]]; then
      echo "[$i] $title — $rating from $votes"
      choices+=("$title|$rating|$votes")
      ((i++))
    fi
    [[ $i -gt 10 ]] && break
  done <<< "$matches"

  if [[ ${#choices[@]} -eq 0 ]]; then
    echo "❌ No valid results found. Marking as DELETE."
    echo -e "$col1\t$col2\t$col3\tDELETE\t" >> "$temp_file"
    continue
  fi

  echo
  echo "➡️  Select a result [1-${#choices[@]}], or press Enter to mark DELETE:"
  sleep 1  # optional delay before prompting user
  read -r choice < /dev/tty

  if [[ -z "$choice" ]]; then
    echo -e "$col1\t$col2\t$col3\tDELETE\t" >> "$temp_file"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#choices[@]} )); then
    selected="${choices[$((choice - 1))]}"
    rating=$(echo "$selected" | cut -d'|' -f2)f[]
    votes=$(echo "$selected" | cut -d'|' -f3)
    echo -e "$col1\t$col2\t$col3\t$rating\t$votes" >> "$temp_file"
  else
    echo "❌ Invalid input. Marking as DELETE."
    echo -e "$col1\t$col2\t$col3\tDELETE\t" >> "$temp_file"
  fi

# Save updated TSV
mv "$temp_file" "$tsv"
echo "✅ Updated: $tsv"
