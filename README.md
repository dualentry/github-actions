# Linear Slack Integration for GitHub Actions

This repository contains reusable GitHub Actions workflows that integrate Linear ticket tracking with Slack notifications. When PRs are created or merged targeting `main`, the workflows automatically:

1. Extract Linear ticket IDs from commits
2. Send formatted notifications to Slack
3. Update Linear ticket status to "Done" after merge

## Prerequisites

Your GitHub organization must have the following secrets configured:

- `LINEAR_API_KEY` - Linear API key with permission to read and update issues
- `SLACK_RELEASE_CHANGELOG_WEBHOOK` - Slack webhook URL for the release changelog channel
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions (no setup needed)

## Ticket Format

The workflows extract ticket IDs from commit messages and PR titles using the following pattern:

- **Format**: `(ACC|DEV|acc|dev)[-_]<number>`
- **Examples**:
  - `ACC-123`
  - `DEV-456`
  - `acc_789`
  - `dev-012`
  - `feat: add new feature (DEV-8139)`
  - `Merge pull request #123 from dualentry/martins/dev-8282-endpoints`

Commits without ticket IDs are automatically skipped.

## Usage

### 1. Setup the Workflows in Your Repository

Create workflow files in your repository that call these reusable workflows.

#### For PR Opened Events

Create `.github/workflows/linear-pr-opened.yml`:

```yaml
name: Linear - PR Opened

on:
  pull_request:
    branches: ["main"]
    types: [opened, reopened, synchronize]

jobs:
  notify:
    uses: dualentry/github-actions/.github/workflows/linear-slack-pr-opened.yml@main
    with:
      base-branch: dev           # Branch to compare against (default: dev)
      environment: production    # Environment name (default: production)
    secrets:
      LINEAR_API_KEY: ${{ secrets.LINEAR_API_KEY }}
      SLACK_RELEASE_CHANGELOG_WEBHOOK: ${{ secrets.SLACK_RELEASE_CHANGELOG_WEBHOOK }}
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### For PR Merged Events

Create `.github/workflows/linear-pr-merged.yml`:

```yaml
name: Linear - PR Merged

on:
  push:
    branches: ["main"]

jobs:
  release:
    uses: dualentry/github-actions/.github/workflows/linear-slack-pr-merged.yml@main
    with:
      base-branch: dev              # Branch to compare against (default: dev)
      environment: production       # Environment name (default: production)
      update-linear-status: true    # Update Linear tickets to Done (default: true)
    secrets:
      LINEAR_API_KEY: ${{ secrets.LINEAR_API_KEY }}
      SLACK_RELEASE_CHANGELOG_WEBHOOK: ${{ secrets.SLACK_RELEASE_CHANGELOG_WEBHOOK }}
```

### 2. Workflow Inputs

#### linear-slack-pr-opened.yml

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `base-branch` | Base branch to compare against | No | `dev` |
| `environment` | Environment name for Slack message | No | `production` |

#### linear-slack-pr-merged.yml

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `base-branch` | Base branch to compare against | No | `dev` |
| `environment` | Environment name for Slack message | No | `production` |
| `update-linear-status` | Whether to update Linear ticket status to Done | No | `true` |

### 3. Example Workflow for Dev Branch

If you want to trigger notifications for `dev` branch as well:

```yaml
name: Linear - Dev Deployment

on:
  push:
    branches: ["dev"]

jobs:
  release:
    uses: dualentry/github-actions/.github/workflows/linear-slack-pr-merged.yml@main
    with:
      base-branch: dev
      environment: dev
      update-linear-status: false  # Don't mark as Done for dev deployments
    secrets:
      LINEAR_API_KEY: ${{ secrets.LINEAR_API_KEY }}
      SLACK_RELEASE_CHANGELOG_WEBHOOK: ${{ secrets.SLACK_RELEASE_CHANGELOG_WEBHOOK }}
```

## Slack Message Format

### PR Opened

```
👀 New PR Ready for Review

Application: `frontend`
Environment: `production`

━━━━━━━━━━━━━━━━━━━━━━━

**A pull request has been opened with the following tickets:**
• Improve bill due_date logic (DEV-8139)
• New endpoint to get organization parent company defaults (DEV-8281)
• Add onboarding checklist visibility endpoints (DEV-8282)

View Pull Request
```

### PR Merged

```
🚀 Tickets Released

Application: `backend`
Environment: `production`

━━━━━━━━━━━━━━━━━━━━━━━

**The following tickets have been released:**
• Improve bill due_date logic (DEV-8139)
• New endpoint to get organization parent company defaults (DEV-8281)
• Add onboarding checklist visibility endpoints (DEV-8282)
```

## Scripts

The repository includes three main scripts:

### extract-tickets.sh

Extracts Linear ticket IDs from git commits between two refs.

```bash
./extract-tickets.sh <base-ref> <head-ref>
# Returns: ["DEV-123", "ACC-456"]
```

### notify-slack.sh

Sends formatted Slack notifications with ticket information.

```bash
./notify-slack.sh <event-type> <tickets-json>
# event-type: "pr_opened" or "pr_merged"
```

### update-linear-status.sh

Updates Linear ticket status to "Done".

```bash
./update-linear-status.sh <tickets-json>
```

## Development

### Testing Locally

You can test the scripts locally:

```bash
# Set required environment variables
export LINEAR_API_KEY="your-key"
export SLACK_RELEASE_CHANGELOG_WEBHOOK="your-webhook"
export REPOSITORY_NAME="test-repo"
export ENVIRONMENT="dev"

# Test ticket extraction
cd .github/scripts
./extract-tickets.sh origin/dev origin/main

# Test Slack notification (requires extracted tickets)
./notify-slack.sh pr_opened '["DEV-123","ACC-456"]'

# Test Linear status update
./update-linear-status.sh '["DEV-123","ACC-456"]'
```

## Troubleshooting

### No tickets found

- Ensure commit messages or PR titles contain ticket IDs in the correct format
- Check that the base branch comparison is correct
- Verify git refs are properly fetched

### Slack notification failed

- Verify `SLACK_RELEASE_CHANGELOG_WEBHOOK` is correctly configured
- Check webhook URL is valid and accessible
- Ensure Slack app has permission to post to the channel

### Linear status update failed

- Verify `LINEAR_API_KEY` has permission to update issues
- Check that "Done" workflow state exists in your Linear workspace
- Ensure ticket IDs are valid and accessible

### Permission denied on scripts

- Make sure scripts are executable: `chmod +x .github/scripts/*.sh`
- The workflows automatically set execute permissions, but manual runs may require this

## License

Internal use only - DualEntry organization.
