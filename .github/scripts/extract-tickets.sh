#!/bin/bash
set -euo pipefail

# Extract Linear ticket IDs from git commits (subject + body)
# Supports formats: [PREFIX]-123 where PREFIX is any 2-10 letter code
# Examples: ACC-123, DEV-456, MREC-789, RECS-012, REP-434, etc.
# Usage: ./extract-tickets.sh <base-ref> <head-ref>

BASE_REF="${1:-origin/dev}"
HEAD_REF="${2:-HEAD}"

# Get all commit messages between base and head (including body)
COMMITS=$(git log --format="%s%n%b" "${BASE_REF}..${HEAD_REF}" 2>/dev/null || echo "")

# Also check PR title if available
PR_TITLE="${PR_TITLE:-}"
ALL_TEXT="${COMMITS}"$'\n'"${PR_TITLE}"

# Extract ticket IDs using regex pattern: [A-Za-z]{2,10}(-|_)<number>
# This will match any prefix: ACC-123, DEV-456, MREC-789, RECS-012, etc.
TICKET_IDS=$(echo "$ALL_TEXT" | grep -oiE '[a-z]{2,10}[-_][0-9]+' | sort -u || true)

if [ -z "$TICKET_IDS" ]; then
  echo "[]"
  exit 0
fi

# Convert to uppercase and normalize separators to dash
NORMALIZED_IDS=$(echo "$TICKET_IDS" | tr '[:lower:]' '[:upper:]' | tr '_' '-' | sort -u)

# Convert to JSON array
JSON_ARRAY="["
FIRST=true
while IFS= read -r ticket; do
  if [ -n "$ticket" ]; then
    if [ "$FIRST" = true ]; then
      JSON_ARRAY="${JSON_ARRAY}\"${ticket}\""
      FIRST=false
    else
      JSON_ARRAY="${JSON_ARRAY},\"${ticket}\""
    fi
  fi
done <<< "$NORMALIZED_IDS"
JSON_ARRAY="${JSON_ARRAY}]"

echo "$JSON_ARRAY"
