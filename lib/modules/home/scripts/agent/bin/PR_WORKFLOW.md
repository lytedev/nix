# Automated PR Submission and CI Monitoring

This directory contains tools for automatically submitting WIP pull requests to Forgejo and monitoring their CI status.

## Tools

### `pr-submit-and-monitor`

Main script that handles the complete PR workflow:
1. Pushes current jujutsu bookmark to remote
2. Creates a PR (or updates existing one)
3. Monitors CI status in real-time
4. Reports success/failure with links to logs

**Usage:**
```bash
# Submit PR and monitor (uses commit message as title)
pr-submit-and-monitor

# Submit as draft PR
pr-submit-and-monitor --draft

# Custom title and body
pr-submit-and-monitor --title "feat: my feature" --body "Description here"
```

**Features:**
- Auto-generates PR title from commit message
- Falls back to WIP prefix if not a conventional commit
- Shows real-time CI status updates
- Colors for easy status identification (✓ green, ✗ red, ⟳ yellow)
- Links to PR and CI logs
- Handles existing PRs gracefully

### `forgejo-token-setup`

Helper script for setting up your Forgejo API token.

**Usage:**
```bash
forgejo-token-setup
```

This will:
1. Guide you through creating a token at https://git.lyte.dev/user/settings/applications
2. Save it securely to `~/.config/forgejo/token`
3. Test the token validity
4. Show instructions for auto-loading (already configured in fish shell)

## Setup

### 1. Install the tools

These scripts are automatically available after rebuilding your home-manager configuration:

```bash
home-manager switch --flake .
```

### 2. Set up your Forgejo API token

```bash
forgejo-token-setup
```

Required permissions:
- `repo` (all)
- `write:repository`
- `read:repository`

### 3. Start using it!

```bash
# Make some changes with jujutsu
jj new
# ... make changes ...
jj describe -m "feat: my awesome feature"

# Create a bookmark
jj bookmark create my-feature

# Submit and monitor!
pr-submit-and-monitor
```

## Example Output

```
Repository: lytedev/nix
Branch: my-feature
Title: feat: add screen locking with swaylock fallback

Pushing branch to remote...
✓ Branch pushed successfully

Creating pull request...
✓ PR created: https://git.lyte.dev/lytedev/nix/pulls/42

Monitoring CI status...
Press Ctrl+C to stop monitoring

[2025-12-06 15:30:00] ⟳ Checks running...
  ⟳ build-host (beefcake): in_progress
  ⟳ build-host (dragon): in_progress
  ⟳ flake-check: in_progress

[2025-12-06 15:32:15] ⟳ Checks running...
  ✓ build-host (beefcake): success
  ⟳ build-host (dragon): in_progress
  ⟳ flake-check: in_progress

[2025-12-06 15:35:42] ✓ All checks passed
  ✓ build-host (beefcake): success
  ✓ build-host (dragon): success
  ✓ flake-check: success

CI completed successfully!
PR: https://git.lyte.dev/lytedev/nix/pulls/42
```

## Integration with Workflow

### Typical Development Flow

1. **Create a workspace for your feature:**
   ```bash
   jj workspace add workspaces/my-feature
   cd workspaces/my-feature
   jj bookmark create my-feature
   ```

2. **Make changes and describe them:**
   ```bash
   jj describe -m "feat(module): add awesome feature

   - Implement X
   - Fix Y
   - Update Z"
   ```

3. **Submit PR and monitor CI:**
   ```bash
   pr-submit-and-monitor
   ```

4. **If CI fails, fix and update:**
   ```bash
   # Make fixes
   jj describe -m "feat(module): add awesome feature (updated)

   - Fixed CI issues
   - ...
   "

   # Push updates (PR will be automatically updated)
   jj git push
   ```

5. **Re-run monitoring if needed:**
   ```bash
   pr-submit-and-monitor  # Will detect existing PR
   ```

### CI Configuration

The CI workflow is defined in `.forgejo/workflows/pre-merge.yaml` and includes:

- Building multiple host configurations in parallel
- Checking the nix flake
- Building the default devShell

All checks must pass before the PR can be merged.

## Troubleshooting

### Token not found

If you see "FORGEJO_TOKEN environment variable is not set":
1. Run `forgejo-token-setup`
2. Reload your shell or run: `set -gx FORGEJO_TOKEN (cat ~/.config/forgejo/token)`

### PR creation fails

- Check your token has the correct permissions
- Verify you're on a jujutsu bookmark (not just a random change)
- Make sure you have push access to the repository

### CI not starting

- Check the PR page to see if workflows are enabled
- Verify the `.forgejo/workflows/` directory exists
- Check Forgejo Actions runner status on the server

## Environment Variables

- `FORGEJO_URL` - Forgejo instance URL (default: `https://git.lyte.dev`)
- `FORGEJO_TOKEN` - API token (automatically loaded from `~/.config/forgejo/token`)

## Future Enhancements

Potential improvements:
- [ ] Support for multiple reviewers
- [ ] Auto-assign labels based on commit message
- [ ] Integration with issue tracking
- [ ] Slack/Discord notifications on CI completion
- [ ] Ability to pause/resume monitoring
- [ ] Save CI logs locally on failure
- [ ] Support for GitHub in addition to Forgejo
