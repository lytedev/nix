# Agents

Instructions for AI coding agents working in this repository.

## Shell

The interactive and login shell on this system — and on the remote hosts, for
both the primary user and `root` — is **fish**, not bash. Shell snippets in this
file, and any command you run over SSH or expect to run interactively, must be
fish-compatible.

Key differences from POSIX/bash to watch for:

- **Variable assignment:** `set var value`, not `var=value`.
- **No heredocs:** fish has no `<<EOF`. Write the file another way, or run the
  block under bash.
- **Logic/operators:** `and` / `or` / `not` are commands (not `&&`/`||`); `;`
  separates statements. Command substitution is `(cmd)`, e.g.
  `nix fmt -- (jj file list)`.
- **Running bash on purpose:** for multi-statement scripts — especially over SSH,
  where `ssh <host> '<cmd>'` lands in fish — wrap them: `bash -c '...'`, or pipe a
  script in with `ssh <host> bash -s < script.sh`.

## Repository Structure

- `lib/modules/nixos/` — active NixOS module configuration
- `lib/modules/home/` — **dead code**, do not edit
- `packages/hosts/` — per-host NixOS configurations
- `dotfiles/` — config files symlinked into `~/.config/`
- `secrets/` — SOPS-encrypted secrets
- `lib/deploy/` — deploy-rs configuration
- `lib/doc/` — long-form documentation
- `issues/` — in-repo issue tracking

## Issue Tracking

Issues are tracked as markdown files in `issues/open/` and `issues/closed/`.
See `issues/README.md` for the convention. One file per issue, status is
directory-based (move between `open/` and `closed/`).

- Before starting work, check `issues/open/` for relevant context
- When creating a new issue, add a `.md` file to `issues/open/` with a `# Title` heading
- When resolving an issue, move its file from `open/` to `closed/`
- Use `**Labels**:` and `**Related**:` metadata lines where helpful

## Dotfiles Convention

Home-manager has been **removed** from this flake. User environment (symlinks, dconf
settings, files) is managed by a custom NixOS-native system in
`lib/modules/nixos/user-env.nix` using `system.userActivationScripts`.

- **Symlinks**: Configured via `lyte.userSymlinks` (e.g. in `lib/modules/nixos/shell-config.nix`)
- **Files**: Configured via `lyte.userFiles`
- **dconf**: Configured via `lyte.dconfSettings`

Actual config content lives in `dotfiles/` and is symlinked into `~/.config/` via
`lyte.userSymlinks` so it can be edited live without rebuilding.

**Important:** Always symlink individual files, never whole directories. Directory-level
symlinks prevent mutable files (like Helix's `runtime/grammars/`) from coexisting in
the same config directory.

**Note:** `lib/modules/home/` still exists but contains **dead code** from the old
home-manager setup. The active configuration is in `lib/modules/nixos/`.

## Version Control

This repo uses **jujutsu (jj)**, not git directly. Use `jj` commands for all
VCS operations.

If asked, setup jj workspaces for separate features somewhere in the following format:
- $CODE/workspaces/$REPO_NAME/$WORKSPACE_NAME
  - $CODE is the related code directory, usually ~/../code (since $HOME is /home/daniel/.home for clutter reasons and the code directory is usually /home/daniel/code)
  - $REPO_NAME would be nix in this case, so going from code/nix to code/workspaces/nix should be obvious
  - $WORKSPACE_NAME should probably just be the branch or bookmark name

## Deploying (deploy-rs)

Remote hosts are deployed via [deploy-rs](https://github.com/serokell/deploy-rs).
Use `nix develop -c deploy` (not comma) to ensure the pinned version from the
devshell is used. Node configuration lives in `lib/deploy/default.nix`. All hosts
are reached over the VPN at `<host>.internal.vpn.h.lyte.dev` and build remotely
by default.

```bash
# Deploy all hosts
nix develop -c deploy .

# Deploy a specific host (skipping checks with -s)
nix develop -c deploy -s --targets ".#beefcake"

# Deploy from remote flake ref without a local clone
nix develop -c deploy -s --targets "git+https://git.lyte.dev/lytedev/nix#beefcake"
```

## Forgejo (fj CLI)
Remote is hosted on Forgejo. Use `fj` (forgejo-cli, available via `nix develop`) for PRs:

```bash
nix develop -c fj pr list
nix develop -c fj pr create "title" --base main --head branch-name --body "description"
nix develop -c fj pr merge <id>
```

## Nix

- Format with `nix fmt`
- Don't waste time waiting for CI for fast things — format code `nix fmt -- (jj file list)`
- Let CI handle big builds; don't build host configs locally unless necessary
