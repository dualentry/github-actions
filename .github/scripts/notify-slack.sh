#!/bin/bash
set -euo pipefail

# Send Slack notification with Linear ticket information
# Usage: ./notify-slack.sh <event-type> <tickets-json>
# Event types: "pr_opened" or "pr_merged"

EVENT_TYPE="${1:-pr_opened}"
TICKETS_JSON="${2:-[]}"
SLACK_WEBHOOK_URL="${SLACK_RELEASE_CHANGELOG_WEBHOOK}"
LINEAR_API_KEY="${LINEAR_API_KEY}"
REPOSITORY_NAME="${REPOSITORY_NAME:-unknown}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"
PR_URL="${PR_URL:-}"

# Exit early if no tickets
if [ "$TICKETS_JSON" = "[]" ] || [ -z "$TICKETS_JSON" ]; then
  echo "No tickets found. Skipping Slack notification."
  exit 0
fi

# Fetch ticket details from Linear
TICKET_DETAILS=""
TICKET_COUNT=$(echo "$TICKETS_JSON" | jq '. | length')

for i in $(seq 0 $((TICKET_COUNT - 1))); do
  TICKET_ID=$(echo "$TICKETS_JSON" | jq -r ".[$i]")

  # Query Linear API for ticket details
  QUERY=$(cat <<EOF
{
  "query": "query { issue(id: \"$TICKET_ID\") { id identifier title url state { name } } }"
}
EOF
)

  RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: ${LINEAR_API_KEY}" \
    -d "$QUERY" \
    https://api.linear.app/graphql)

  # Extract title and URL
  TITLE=$(echo "$RESPONSE" | jq -r '.data.issue.title // "Unknown"')
  URL=$(echo "$RESPONSE" | jq -r '.data.issue.url // ""')

  if [ "$TITLE" != "Unknown" ]; then
    if [ -n "$URL" ]; then
      TICKET_DETAILS="${TICKET_DETAILS}\n• <${URL}|${TITLE}> (${TICKET_ID})"
    else
      TICKET_DETAILS="${TICKET_DETAILS}\n• ${TITLE} (${TICKET_ID})"
    fi
  else
    TICKET_DETAILS="${TICKET_DETAILS}\n• ${TICKET_ID}"
  fi
done

# Build Slack message based on event type
if [ "$EVENT_TYPE" = "pr_opened" ]; then
  EMOJI=":eyes:"
  TITLE_TEXT="New PR Ready for Review"
  MESSAGE_TEXT="A pull request has been opened with the following tickets:"
elif [ "$EVENT_TYPE" = "pr_merged" ]; then
  EMOJI=":rocket:"
  TITLE_TEXT="Tickets Released"
  MESSAGE_TEXT="The following tickets have been released:"
else
  EMOJI=":information_source:"
  TITLE_TEXT="Linear Tickets Update"
  MESSAGE_TEXT="Ticket information:"
fi

# Create Slack message payload
SLACK_PAYLOAD=$(cat <<EOF
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "${EMOJI} ${TITLE_TEXT}",
        "emoji": true
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Application:*\n\`${REPOSITORY_NAME}\`"
        },
        {
          "type": "mrkdwn",
          "text": "*Environment:*\n\`${ENVIRONMENT}\`"
        }
      ]
    },
    {
      "type": "divider"
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*${MESSAGE_TEXT}*${TICKET_DETAILS}"
      }
    }
EOF
)

# Add PR URL if available
if [ -n "$PR_URL" ]; then
  SLACK_PAYLOAD=$(cat <<EOF
${SLACK_PAYLOAD},
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "<${PR_URL}|View Pull Request>"
      }
    }
EOF
)
fi

# Close the JSON
SLACK_PAYLOAD="${SLACK_PAYLOAD}
  ]
}"

# Send to Slack
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$SLACK_PAYLOAD" \
  "$SLACK_WEBHOOK_URL")

if [ "$RESPONSE" = "ok" ]; then
  echo "Slack notification sent successfully!"
else
  echo "Failed to send Slack notification. Response: $RESPONSE"
  exit 1
fi
