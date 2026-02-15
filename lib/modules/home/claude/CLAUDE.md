# This file is managed by Nix (Home Manager). Do not edit it directly.
# Source: lib/modules/home/claude/CLAUDE.md in the nix config repo.
# To modify, edit the source and rebuild (e.g., `nh os switch`).

# Matrix Messaging

Send messages to Matrix rooms (bridged to Slack/Discord) via hookshot webhooks:

```bash
claude-matrix-send <room> "message"
```

Available rooms:
- `notify` — Claude notifications (idle, permission prompts)
- `hive` — ccode hive general room
- `code-review` — #code-review Slack channel (via relay)

Notifications are sent automatically by hooks on idle/permission prompts. Use `claude-matrix-send` to proactively communicate — e.g., requesting code review, reporting task completion, or asking questions.

# Screenshots

The latest screenshot/clipboard image can be found in `~/img/scrots/` (e.g. `clipshot_2026-02-13_13-29-03.png`). Use `ltl ~/img/scrots/` to find the most recent file. You can read these images directly with the Read tool.

# Package Management
When running commands or tools that may not be installed on the system, prefer using `nix shell` or `comma` to run them without permanent installation:

- Use `comma` (`,`) for quick execution: `, program-name args`
- Use `nix shell nixpkgs#program-name` for more complex setups
- Only install packages globally if absolutely necessary and the user explicitly requests it

# Development Environment
This system uses Nix for package management. Always consider if a tool can be run via nix shell or comma before suggesting installation.

# Code Style
Follow standard coding practices and use appropriate tools for the language/framework being used.

# Jujutsu (jj) - Use instead of git

This host uses jj (jujutsu) for version control. Prefer jj commands over git.

## Quick Reference

| Task | jj command |
|------|------------|
| Status | `jj status` or `jj st` |
| Diff working copy | `jj diff` |
| Diff specific revision | `jj diff -r @-` |
| Log/history | `jj log` |
| Short log | `jj log --no-graph -r ::@` |
| Describe (commit msg) | `jj describe -m "message"` |
| New empty change | `jj new` |
| New change on specific rev | `jj new <rev>` |
| Squash into parent | `jj squash` |
| Split a change | `jj split` |
| Edit a prior change | `jj edit <rev>` |
| Abandon change | `jj abandon` |
| Rebase | `jj rebase -d <dest>` |
| Show a revision | `jj show <rev>` |

## Bookmarks (like git branches)

| Task | jj command |
|------|------------|
| List bookmarks | `jj bookmark list` |
| Create bookmark | `jj bookmark create <name>` |
| Move bookmark to current | `jj bookmark set <name>` |
| Delete bookmark | `jj bookmark delete <name>` |

## Remote Operations

| Task | jj command |
|------|------------|
| Fetch | `jj git fetch` |
| Push | `jj git push` |
| Push specific bookmark | `jj git push -b <bookmark>` |
| Clone | `jj git clone <url>` |

## Revsets (revision selectors)

- `@` - current working copy
- `@-` - parent of working copy
- `@--` - grandparent
- `<bookmark>` - bookmark by name
- `<change-id>` - by change ID (the `k-z` letters)
- `<commit-id>` - by commit hash
- `trunk()` - main/master branch

## Key Differences from Git

1. **No staging area** - all changes in working copy are automatically included
2. **Working copy is a commit** - `@` always points to a real (mutable) commit
3. **Describe vs commit** - use `jj describe` to set message, `jj new` to start next change
4. **Bookmarks not branches** - bookmarks are just pointers, not tied to commits
5. **Change IDs** - immutable IDs that survive rebases (the `k-z` letter sequences)
6. **Conflict markers are commits** - conflicts are stored in commits, not working copy state

## Common Workflows

```bash
# Make changes and describe them
jj describe -m "Add feature X"
jj new  # Start fresh change for next work

# Interactive rebase/edit history
jj rebase -d main  # Rebase current onto main

# Push to remote
jj git push -b <bookmark>

# Undo last operation
jj undo

