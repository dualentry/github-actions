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

# Fetch ticket details from Linear and store in array
TICKET_COUNT=$(echo "$TICKETS_JSON" | jq '. | length')
MAX_TICKETS_PER_MESSAGE=10  # Tickets per Slack message

# Fetch all ticket details
declare -a TICKET_LINES
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

  # Remove newlines from title (jq will handle other escaping)
  TITLE=$(echo "$TITLE" | tr -d '\n\r')

  if [ "$TITLE" != "Unknown" ]; then
    if [ -n "$URL" ]; then
      TICKET_LINES+=("• <${URL}|${TITLE}> (${TICKET_ID})")
    else
      TICKET_LINES+=("• ${TITLE} (${TICKET_ID})")
    fi
  else
    TICKET_LINES+=("• ${TICKET_ID}")
  fi
done

# Build Slack message based on event type
if [ "$EVENT_TYPE" = "pr_opened" ]; then
  EMOJI=":eyes:"
  TITLE_TEXT="New PR Ready for Review"
  MESSAGE_TEXT="A pull request has been opened with *${TICKET_COUNT} Linear tickets*:"
elif [ "$EVENT_TYPE" = "pr_merged" ]; then
  EMOJI=":rocket:"
  TITLE_TEXT="Tickets Released"
  MESSAGE_TEXT="*${TICKET_COUNT} tickets* have been released:"
else
  EMOJI=":information_source:"
  TITLE_TEXT="Linear Tickets Update"
  MESSAGE_TEXT="*${TICKET_COUNT} tickets* included:"
fi

# Calculate number of messages needed
TOTAL_MESSAGES=$(( (TICKET_COUNT + MAX_TICKETS_PER_MESSAGE - 1) / MAX_TICKETS_PER_MESSAGE ))

# Send messages (split into chunks if needed)
for msg_num in $(seq 1 $TOTAL_MESSAGES); do
  START_IDX=$(( (msg_num - 1) * MAX_TICKETS_PER_MESSAGE ))
  END_IDX=$(( msg_num * MAX_TICKETS_PER_MESSAGE - 1 ))

  # Don't exceed array bounds
  if [ $END_IDX -ge $TICKET_COUNT ]; then
    END_IDX=$((TICKET_COUNT - 1))
  fi

  # Build ticket list for this message (join with newlines)
  TICKET_DETAILS=""
  for i in $(seq $START_IDX $END_IDX); do
    if [ -n "$TICKET_DETAILS" ]; then
      TICKET_DETAILS="${TICKET_DETAILS}
${TICKET_LINES[$i]}"
    else
      TICKET_DETAILS="${TICKET_LINES[$i]}"
    fi
  done

  # Build JSON payload using jq for proper escaping
  if [ $msg_num -eq 1 ]; then
    # First message with full header
    if [ -n "$PR_URL" ]; then
      SLACK_PAYLOAD=$(jq -n \
        --arg emoji "$EMOJI" \
        --arg title "$TITLE_TEXT" \
        --arg app "$REPOSITORY_NAME" \
        --arg env "$ENVIRONMENT" \
        --arg msg "$MESSAGE_TEXT" \
        --arg tickets "$TICKET_DETAILS" \
        --arg pr_url "$PR_URL" \
        '{
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: ($emoji + " " + $title),
                emoji: true
              }
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: ("*Application:*\n`" + $app + "`")
                },
                {
                  type: "mrkdwn",
                  text: ("*Environment:*\n`" + $env + "`")
                }
              ]
            },
            {
              type: "divider"
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $msg
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $tickets
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: ("<" + $pr_url + "|View Pull Request>")
              }
            }
          ]
        }')
    else
      SLACK_PAYLOAD=$(jq -n \
        --arg emoji "$EMOJI" \
        --arg title "$TITLE_TEXT" \
        --arg app "$REPOSITORY_NAME" \
        --arg env "$ENVIRONMENT" \
        --arg msg "$MESSAGE_TEXT" \
        --arg tickets "$TICKET_DETAILS" \
        '{
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: ($emoji + " " + $title),
                emoji: true
              }
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: ("*Application:*\n`" + $app + "`")
                },
                {
                  type: "mrkdwn",
                  text: ("*Environment:*\n`" + $env + "`")
                }
              ]
            },
            {
              type: "divider"
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $msg
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $tickets
              }
            }
          ]
        }')
    fi
  else
    # Subsequent messages with part number
    PART_TEXT="*Part ${msg_num}/${TOTAL_MESSAGES}*"
    if [ -n "$PR_URL" ]; then
      SLACK_PAYLOAD=$(jq -n \
        --arg part "$PART_TEXT" \
        --arg tickets "$TICKET_DETAILS" \
        --arg pr_url "$PR_URL" \
        '{
          blocks: [
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $part
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $tickets
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: ("<" + $pr_url + "|View Pull Request>")
              }
            }
          ]
        }')
    else
      SLACK_PAYLOAD=$(jq -n \
        --arg part "$PART_TEXT" \
        --arg tickets "$TICKET_DETAILS" \
        '{
          blocks: [
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $part
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: $tickets
              }
            }
          ]
        }')
    fi
  fi

  # Send to Slack
  RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$SLACK_PAYLOAD" \
    "$SLACK_WEBHOOK_URL")

  if [ "$RESPONSE" = "ok" ]; then
    echo "Slack notification part ${msg_num}/${TOTAL_MESSAGES} sent successfully!"
  else
    echo "Failed to send Slack notification part ${msg_num}/${TOTAL_MESSAGES}. Response: $RESPONSE"
    exit 1
  fi

  # Small delay between messages to avoid rate limiting
  if [ $msg_num -lt $TOTAL_MESSAGES ]; then
    sleep 1
  fi
done

echo "All ${TOTAL_MESSAGES} Slack message(s) sent successfully!"
