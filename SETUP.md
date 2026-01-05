# Setup Guide for Consuming Repositories

This guide explains how to integrate the Linear-Slack workflows into your repository.

## Prerequisites

Organization has already configured the following secrets:

1. `LINEAR_API_KEY`
2. `SLACK_RELEASE_CHANGELOG_WEBHOOK`
3. `GITHUB_TOKEN` - Automatically provided by GitHub Actions (no setup needed)

## Step-by-Step Integration

### 1. Copy Example Workflows

Copy the example workflow files from the `examples/` directory to your repository:

```bash
# In your repository
mkdir -p .github/workflows

# Copy the PR opened workflow
cp path/to/github-actions/examples/linear-pr-opened.yml .github/workflows/

# Copy the PR merged workflow
cp path/to/github-actions/examples/linear-pr-merged.yml .github/workflows/
```

### 2. Customize Configuration

Adjust the workflow parameters based on your needs:

#### For Production Repositories (deploying to `main`)

```yaml
with:
  base-branch: dev              # Branch where PRs are created from
  environment: production       # Show as "production" in Slack
  update-linear-status: true    # Mark tickets as Done
```

#### For Development Repositories

```yaml
with:
  base-branch: dev
  environment: dev
  update-linear-status: false   # Don't mark as Done until production
```

### 3. Commit and Push

```bash
git add .github/workflows/linear-*.yml
git commit -m "Add Linear-Slack integration workflows"
git push
```

### 4. Test the Integration

#### Test PR Opened Workflow

1. Create a branch from `dev` with a commit containing a Linear ticket ID:

   ```bash
   git checkout dev
   git pull
   git checkout -b test/dev-123-test-integration
   git commit --allow-empty -m "test: DEV-123 test integration"
   git push -u origin test/dev-123-test-integration
   ```

2. Open a PR against `main`
3. Check that:
   - Slack notification was sent
   - PR comment was added with ticket list
   - GitHub Actions workflow succeeded

#### Test PR Merged Workflow

1. Merge the test PR to `main`
2. Check that:
   - Slack "Tickets Released" notification was sent
   - Linear ticket status changed to "Done" (if enabled)
   - GitHub Actions workflow succeeded

## Branch Strategy

This integration assumes the following branch strategy:

```
dev (development) → main (production)
```

- Developers create branches from `dev`
- PRs are opened against `main` (promoting dev to production)
- When PR is merged to `main`, tickets are released

If your branch strategy is different, adjust the `base-branch` parameter accordingly.

## Common Configurations

### Configuration 1: Standard Two-Branch Setup

```
Branches: dev → main
PR Target: main
Base Branch: dev
Update Status: true (only on main)
```

```yaml
# .github/workflows/linear-pr-opened.yml
on:
  pull_request:
    branches: ["main"]

with:
  base-branch: dev
  environment: production
```

```yaml
# .github/workflows/linear-pr-merged.yml
on:
  push:
    branches: ["main"]

with:
  base-branch: dev
  environment: production
  update-linear-status: true
```

### Configuration 2: Multiple Environments

```yaml
# For staging deployments (don't mark Done)
on:
  push:
    branches: ["staging"]

with:
  base-branch: dev
  environment: staging
  update-linear-status: false
```

```yaml
# For production deployments (mark Done)
on:
  push:
    branches: ["main"]

with:
  base-branch: staging
  environment: production
  update-linear-status: true
```

### Configuration 3: Feature Branch to Main

If you work directly from feature branches to main:

```yaml
with:
  base-branch: main  # Compare against main itself
  environment: production
  update-linear-status: true
```

## Troubleshooting

### Workflow not triggering

**Problem**: Workflow doesn't run when PR is opened
**Solution**:

- Check that workflow file is in `.github/workflows/` directory
- Verify the file has `.yml` or `.yaml` extension
- Ensure the `on.pull_request.branches` matches your PR target branch

### Secrets not found

**Problem**: `Error: Input required and not supplied: LINEAR_API_KEY`
**Solution**:

- Verify secrets are created at organization level (not repository level)
- Check that your repository has access to organization secrets
- Ensure secret names match exactly (case-sensitive)

### No tickets found

**Problem**: Workflow runs but says "No tickets found"
**Solution**:

- Check commit messages contain ticket IDs in correct format (`DEV-123` or `acc_456`)
- Verify the `base-branch` parameter points to the correct branch
- Ensure git refs are being fetched correctly

### Linear status not updating

**Problem**: Tickets not marked as "Done"
**Solution**:

- Verify `update-linear-status: true` is set
- Check that Linear API key has permission to update issues
- Confirm "Done" state exists in your Linear workspace
- Check workflow logs for specific error messages

### Slack notification not sent

**Problem**: No message appears in Slack channel
**Solution**:

- Verify Slack webhook URL is correct
- Check that webhook has permission to post to the target channel
- Test webhook manually using curl:

  ```bash
  curl -X POST -H 'Content-Type: application/json' \
    -d '{"text":"Test message"}' \
    YOUR_WEBHOOK_URL
  ```

## Next Steps

After successful integration:

1. **Train your team**: Make sure developers include Linear ticket IDs in commits
2. **Monitor notifications**: Watch Slack channel to verify notifications are working
3. **Adjust as needed**: Fine-tune the `base-branch` and `environment` parameters
4. **Roll out to other repos**: Repeat this process for other repositories in your organization

## Support

For issues or questions:

- Check the main [README.md](./README.md) for detailed documentation
- Review GitHub Actions logs for error messages
- Contact the DevOps team for assistance
