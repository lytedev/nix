> This file is managed by Nix. Prefer editing in ~/.config/home-manager in lib/modules/home/claude/CLAUDE.md in the nix config repo.

# Package Management

When running commands or tools that may not be installed on the system, prefer using `nix shell` or `comma` to run them without permanent installation:
This system uses Nix for package management. Always consider if a tool can be run via nix shell or comma before suggesting installation.

- Use `comma` (`,`) for quick execution: `, program-name args`
- Use `nix shell nixpkgs#program-name` for more complex setups
- Otherwise, permanent updates to the system should go in ~/.config/home-manager and be coordinated with the user if leaving the current project

# Code Style

Follow standard coding practices and use appropriate tools for the language/framework being used.
Format code using the configured formatter _before_ pushing.
Avoid lines of code that require comments to clarify what something _is_.
Instead, bind the value to a name or put it in a constant or map with a good
name or key that clearly indicates the purpose.
```bash
# bad
IP="192.168.0.1" # beefcake
# good
BEEFCAKE_IP="192.168.0.1"
IP="$BEEFCAKE_IP"
```

# Citing Documentation

When you claim something is "documented", described in the docs, or part of an
official API/spec — **make every effort to provide a permanent URL** to that
documentation, not just an assertion that it exists. A bare "this is documented"
(or worse, a half-remembered claim that it's documented) is not useful and is
easy to get wrong from memory.

- **Prefer stable, permanent links:** versioned doc URLs, commit/tag-pinned
  source links (e.g. GitHub `/blob/<sha>/…` permalinks, not `/blob/main/…`),
  anchored sections. Avoid URLs that drift or rot (`latest`, mutable branches,
  search results).
- **Verify before asserting.** If you're recalling from training rather than a
  source you can point to, say so plainly, and prefer to look it up (WebFetch /
  WebSearch / read the actual file) and link what you find rather than stating it
  as settled fact.
- If you genuinely can't find a URL, say that explicitly ("I believe X but
  couldn't find a citation") instead of implying documentation backs you up.

# Pull Request Scope

**One PR does one thing.** Push back hard when a change starts to do more than
one thing at once — the canonical trap is introducing a new feature/service
_and_ overhauling shared primitives (auth, config, common utilities) in the same
PR. If you notice this happening (or I start steering you into it), stop and call
it out before continuing.

The most common form is the urge to deduplicate. When the new work resembles
existing code, **do not refactor the shared/common code in the same PR** as the
feature. Resist the instinct to kill copypasta inline. The refactor is always its
_own_ PR, sequenced one of two ways:

1. **Extract-first (strongly preferred):** land the shared abstraction as a
   standalone PR first, then build the new feature on top of it. Do this when the
   extraction is small and well-understood.
2. **Duplicate-now, dedupe-later:** copy/paste the similar code to ship the
   feature, then deduplicate in a **fast-follow PR**. Fall back to this only when
   extracting first would be larger or riskier than the feature itself — better
   to live with temporary copypasta than to entangle a big refactor with new
   behavior.

In both cases the dedup/extraction is a separate, linked PR — never folded into
the feature.

**Why:** mixing a new feature with a refactor of shared code couples unrelated
risk, makes the diff hard to review (reviewers can't tell behavior changes from
mechanical moves), and balloons scope. Splitting keeps each PR small, reviewable,
and independently revertable.

When you spot a refactor that should be split out, **link it to the upcoming
work** — note the follow-up explicitly (an issue, a TODO, or a PR description
line referencing the feature it supports) so the dedup actually happens and
isn't lost.

# Jujutsu (jj) - Use instead of git

This host uses jj (jujutsu) for version control. Prefer jj commands over git.

## Quick Reference

| Task                       | jj command                 |
| -------------------------- | -------------------------- |
| Status                     | `jj status` or `jj st`     |
| Diff working copy          | `jj diff`                  |
| Diff specific revision     | `jj diff -r @-`            |
| Log/history                | `jj log`                   |
| Short log                  | `jj log --no-graph -r ::@` |
| Describe (commit msg)      | `jj describe -m "message"` |
| New empty change           | `jj new`                   |
| New change on specific rev | `jj new <rev>`             |
| Squash into parent         | `jj squash`                |
| Split a change             | `jj split`                 |
| Edit a prior change        | `jj edit <rev>`            |
| Abandon change             | `jj abandon`               |
| Rebase                     | `jj rebase -d <dest>`      |
| Show a revision            | `jj show <rev>`            |

## Bookmarks (like git branches)

| Task                     | jj command                  |
| ------------------------ | --------------------------- |
| List bookmarks           | `jj bookmark list`          |
| Create bookmark          | `jj bookmark create <name>` |
| Move bookmark to current | `jj bookmark set <name>`    |
| Delete bookmark          | `jj bookmark delete <name>` |

## Remote Operations

| Task                   | jj command                  |
| ---------------------- | --------------------------- |
| Fetch                  | `jj git fetch`              |
| Push                   | `jj git push`               |
| Push specific bookmark | `jj git push -b <bookmark>` |
| Clone                  | `jj git clone <url>`        |

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
   - Prefer putting details in commit messages, which are durable and
     distributed with the repository, not PR descriptions, which are only
     available if there's a forge to store them
4. **Bookmarks not branches** - bookmarks are just pointers, not tied to commits
5. **Change IDs** - immutable IDs that survive rebases (the `k-z` letter sequences)
6. **Conflict markers are commits** - conflicts are stored in commits, not working copy state

## Common Workflows

Unless otherwise specified, prefer _not_ squashing changes into the same commit.
Having the full commit history of all changes made during development is more
valuable.

Instead, prefer `jj desc` to describe the current changeset, `jj tug` to update
the bookmark associated with the work, `jj push` to ensure it is sync'd up, then
`jj new` to have a fresh commit for the next set of changes. Don't squash unless
specifically asked. Double check the commit's contents do not include files that
should be gitignored.

**CRITICAL: Never rewrite a change after it has been pushed** unless the user
explicitly asks you to clean up history. Once you `jj push` a change, that commit
hash is on the remote. If you then `jj describe` or otherwise rewrite it, the
local copy gets a new hash but the remote still has the old one. The next
`jj git fetch` will bring back the remote's version, creating **divergent
changes** (multiple commits sharing the same change ID). This is messy to clean
up. Always `jj new` before making further modifications after pushing.

Pushed changes are configured as immutable via `immutable_heads()` in the jj
config — jj will **refuse** to rewrite them. If jj errors with "immutable", do
`jj new` first, then make your changes in the new commit.

**Exception: rebasing is always safe** with `--ignore-immutable`. Rebasing only
changes parentage, not content, and jj preserves change IDs across rebases. Use
`jj rebase --ignore-immutable` freely when rebasing branches onto updated trunk
or main. This does not risk divergent changes.

```bash
# Make changes and describe them
jj describe -m "feat: add feature X"  # Prefer conventional commit formatting
jj tug  # Move the bookmark for the current chunk of work OR
jj bookmark create $BOOKMARK  # Create a bookmark if one does not yet exist
jj push  # Push the work up (may need `-b $BOOKMARK` if a new one was created)
jj new  # Start fresh change for next work

# Interactive rebase/edit history
jj rebase -d main  # Rebase current onto main

# Undo last operation
jj undo
```

After pushing, if you need to make follow-up changes, use `jj new` to create a
fresh commit, then `jj tug` to advance the bookmark forward to include it. Do
**not** squash or rebase to fold changes into already-pushed commits — that
rewrites history. `jj tug` (alias for `jj bookmark move`) advances the bookmark
pointer to the latest commit while preserving the full commit chain.

# Monitoring & Waiting

When waiting on CI, remote builds, or long-running processes, prefer watch/poll
commands over `sleep N && check`:

- **GitHub Actions**: `gh pr checks --watch` or `gh run watch`
- **systemd services**: `journalctl -u <service> -f` (follow mode)
- **General processes**: prefer tools with built-in watch/follow modes

Avoid `sleep 120 && ssh ... journalctl` patterns; use streaming/follow output instead.
