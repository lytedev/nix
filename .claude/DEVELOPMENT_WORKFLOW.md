# Development Workflow for Claude Agents

This document describes the standard development workflow for implementing features in this NixOS configuration repository. Follow this process by default when the user requests a feature or fix.

## Standard Feature Development Flow

### 1. Create a Workspace and Bookmark

When a user requests a feature or fix:

```bash
# Create a workspace in the workspaces/ directory
jj workspace add workspaces/feature-name

# Switch to the workspace (if not automatic)
cd workspaces/feature-name

# Create a bookmark for the feature
jj bookmark create feature-name
```

**Guidelines:**
- Use descriptive, kebab-case names (e.g., `niri-power-management`, `add-docker-support`)
- Workspaces are gitignored, so they won't clutter the repository
- One workspace per feature/fix

### 2. Implement the Feature

Make your changes in the workspace:

```bash
# Edit files as needed
# ...

# Describe your changes with a good commit message
jj describe -m "feat(module): description of changes

Detailed explanation of what was implemented and why.
- Bullet points for key changes
- Reference any issues or TODOs addressed"
```

**Commit Message Guidelines:**
- Use conventional commit format: `type(scope): description`
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`, `style`
- Keep first line under 72 characters
- Add detailed body explaining the "why" not the "what"

### 3. Fetch and Rebase to Latest Main

Before submitting, ensure your changes are based on the latest main:

```bash
# Fetch latest changes
jj git fetch

# Rebase your bookmark onto main
jj rebase -r @ -d main@origin

# Check for conflicts
jj status
```

**If there are conflicts:**
- Resolve them manually
- Update your commit description if needed

### 4. Submit PR and Monitor CI

Use the automated PR submission and monitoring tool:

```bash
# Set up Forgejo token (first time only)
forgejo-token-setup

# Load token for current session
export FORGEJO_TOKEN="$(cat ~/.config/forgejo/token)"

# Submit PR and monitor CI
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor
```

The tool will:
- Push your bookmark to the remote
- Create a new PR (or update existing)
- Monitor CI status in real-time
- Report success or failure with links

**Alternative: Monitor existing PR**
```bash
# Load token
export FORGEJO_TOKEN="$(cat ~/.config/forgejo/token)"

# Monitor by bookmark
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor --monitor-only

# Monitor specific PR number
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor --pr 123
```

### 5. Handle CI Failures

If CI fails:

1. **Check the logs** at the URL provided by the monitoring tool
2. **Identify the failure**:
   - Build failures (syntax errors, missing dependencies)
   - Test failures
   - Flake check failures
3. **Fix the issues** in your workspace
4. **Update the commit**:
   ```bash
   jj describe -m "updated commit message"
   ```
5. **Push and monitor again**:
   ```bash
   jj git push --branch feature-name
   export FORGEJO_TOKEN="$(cat ~/.config/forgejo/token)"
   bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor --monitor-only
   ```

### 6. Iterate Until CI Passes

Repeat step 5 until all CI checks pass. The monitoring tool will automatically detect when all checks succeed.

### 7. Request Review (if needed)

Once CI passes:
- Inform the user that the PR is ready
- Provide the PR URL
- Wait for their review or approval before merging

## Quick Reference Commands

```bash
# Create workspace and bookmark
jj workspace add workspaces/feature-name
cd workspaces/feature-name
jj bookmark create feature-name

# Describe changes
jj describe -m "feat: description"

# Fetch and rebase
jj git fetch
jj rebase -r @ -d main@origin

# Load token
export FORGEJO_TOKEN="$(cat ~/.config/forgejo/token)"

# Submit PR and monitor
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor

# Monitor only
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor --monitor-only

# Review PR comments
bash lib/modules/home/scripts/agent/bin/pr-review-comments 177

# Fix and update
# ... make changes ...
jj describe -m "updated message"
jj git push --branch feature-name

# Check status
jj status
jj log -r @ -n 3
```

## Workspace Management

**List workspaces:**
```bash
jj workspace list
```

**Remove completed workspace:**
```bash
jj workspace forget feature-name
rm -rf workspaces/feature-name
```

**Switch between workspaces:**
```bash
cd workspaces/feature-name
# or
cd ..  # back to main workspace
```

## CI Configuration

The CI runs on Forgejo Actions and is configured in `.forgejo/workflows/pre-merge.yaml`.

**Current CI checks:**
- **build-host**: Builds multiple NixOS host configurations in parallel
  - beefcake, router, rascal, dragon, foxtrot, flipflop, steamdeck
- **build-devshell**: Builds the default development shell
- **flake-check**: Runs `nix flake check` to validate the flake

All checks must pass before the PR can be merged.

## Troubleshooting

### "No bookmark found for current change"
```bash
# Create a bookmark
jj bookmark create feature-name
```

### "Refusing to create new remote bookmark"
The script should handle this automatically with `--allow-new`. If not, manually push:
```bash
jj git push --branch feature-name --allow-new
```

### "FORGEJO_TOKEN environment variable is not set"
```bash
# Set up token
forgejo-token-setup

# Or manually export
export FORGEJO_TOKEN=$(cat ~/.config/forgejo/token)
```

### Bookmark has trailing asterisk (*)
The asterisk indicates a modified bookmark. The script automatically strips it - no action needed.

### PR monitoring found wrong PR
This was a bug that has been fixed. The script now properly filters PRs by head branch name.

## Best Practices

1. **Always create a workspace** for non-trivial changes
2. **Use descriptive bookmark names** that reflect the feature
3. **Write good commit messages** following conventional commit format
4. **Rebase before submitting** to avoid merge conflicts
5. **Monitor CI actively** and fix failures promptly
6. **Keep commits focused** - one feature/fix per PR
7. **Clean up workspaces** after PRs are merged

## Example: Complete Flow

```bash
# User: "Add support for Docker in NixOS configuration"

# 1. Create workspace
jj workspace add workspaces/add-docker-support
cd workspaces/add-docker-support
jj bookmark create add-docker-support

# 2. Implement feature
# ... edit files ...
jj describe -m "feat(nixos): add Docker support

Enable Docker daemon with proper configuration.
- Add virtualisation.docker module
- Configure user permissions
- Add docker-compose package"

# 3. Fetch and rebase
jj git fetch
jj rebase -r @ -d main@origin

# 4. Submit and monitor
export FORGEJO_TOKEN="$(cat ~/.config/forgejo/token)"
bash lib/modules/home/scripts/agent/bin/pr-submit-and-monitor

# CI output shows:
# ✓ Branch pushed successfully
# ✓ PR created: https://git.lyte.dev/lytedev/nix/pulls/178
# ⟳ Checks running...
# ✓ All checks passed!

# 5. Inform user
# "PR #178 has been created and all CI checks passed! Ready for review."
```

## Notes for Claude Agents

- **Proactively follow this workflow** when implementing features
- **Use the TodoWrite tool** to track progress through the steps
- **Communicate status** to the user at each major step
- **Handle errors gracefully** and explain issues clearly
- **Don't wait for explicit instructions** - follow the flow automatically
- **Update this document** if the workflow changes or improves
