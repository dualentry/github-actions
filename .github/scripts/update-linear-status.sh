#!/bin/bash
set -euo pipefail

# Update Linear ticket status to "Done"
# Usage: ./update-linear-status.sh <tickets-json>

TICKETS_JSON="${1:-[]}"
LINEAR_API_KEY="${LINEAR_API_KEY}"

# Exit early if no tickets
if [ "$TICKETS_JSON" = "[]" ] || [ -z "$TICKETS_JSON" ]; then
  echo "No tickets to update."
  exit 0
fi

TICKET_COUNT=$(echo "$TICKETS_JSON" | jq '. | length')
echo "Updating status for $TICKET_COUNT tickets..."

# Update each ticket
UPDATED_COUNT=0
FAILED_COUNT=0

for i in $(seq 0 $((TICKET_COUNT - 1))); do
  TICKET_ID=$(echo "$TICKETS_JSON" | jq -r ".[$i]")

  # Get the issue ID, current state, and team's Done state in one query
  ISSUE_QUERY=$(cat <<EOF
{
  "query": "query { issue(id: \"$TICKET_ID\") { id identifier state { name } team { states { nodes { id name } } } } }"
}
EOF
)

  ISSUE_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -d "$ISSUE_QUERY" \
    https://api.linear.app/graphql)

  ISSUE_ID=$(echo "$ISSUE_RESPONSE" | jq -r '.data.issue.id // empty')
  CURRENT_STATE=$(echo "$ISSUE_RESPONSE" | jq -r '.data.issue.state.name // "Unknown"')

  if [ -z "$ISSUE_ID" ]; then
    echo "  [SKIP] ${TICKET_ID} - Issue not found or no access"
    ((FAILED_COUNT++))
    continue
  fi

  if [ "$CURRENT_STATE" = "Done" ]; then
    echo "  [SKIP] ${TICKET_ID} - Already in Done state"
    ((UPDATED_COUNT++))
    continue
  fi

  # Get the Done state ID for this issue's team
  DONE_STATE_ID=$(echo "$ISSUE_RESPONSE" | jq -r '.data.issue.team.states.nodes[] | select(.name == "Done") | .id' | head -n1)

  if [ -z "$DONE_STATE_ID" ]; then
    echo "  [FAIL] ${TICKET_ID} - Could not find 'Done' state for issue's team"
    ((FAILED_COUNT++))
    continue
  fi

  # Update the issue state
  UPDATE_QUERY=$(cat <<EOF
{
  "query": "mutation { issueUpdate(id: \"$ISSUE_ID\", input: { stateId: \"$DONE_STATE_ID\" }) { success issue { identifier state { name } } } }"
}
EOF
)

  UPDATE_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -d "$UPDATE_QUERY" \
    https://api.linear.app/graphql)

  SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.data.issueUpdate.success // false')

  if [ "$SUCCESS" = "true" ]; then
    NEW_STATE=$(echo "$UPDATE_RESPONSE" | jq -r '.data.issueUpdate.issue.state.name')
    echo "  [OK] ${TICKET_ID} - Updated from '${CURRENT_STATE}' to '${NEW_STATE}'"
    ((UPDATED_COUNT++))
  else
    ERROR=$(echo "$UPDATE_RESPONSE" | jq -r '.errors[0].message // "Unknown error"')
    echo "  [FAIL] ${TICKET_ID} - ${ERROR}"
    ((FAILED_COUNT++))
  fi
done

echo ""
echo "Summary: $UPDATED_COUNT updated, $FAILED_COUNT failed"

if [ "$FAILED_COUNT" -gt 0 ]; then
  exit 1
fi
