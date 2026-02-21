if asked, setup jj workspaces for separate features somewhere in the following format:
- $CODE/workspaces/$REPO_NAME/$WORKSPACE_NAME
  - $CODE is the related code directory, usually ~/../code (since $HOME is /home/daniel/.home for clutter reasons and the code directory is usually /home/daniel/code)
  - $REPO_NAME would be nix in this case, so going from code/nix to code/workspaces/nix should be obvious
  - $WORKSPACE_NAME should probably just be the branch or bookmark name

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

## Forgejo (tea CLI)
Remote is hosted on Forgejo. Use `tea` for issues/PRs:

```bash
tea issue list
tea issue create -t "title" -d "description"
tea pr list
tea pr create              # interactive
tea pr merge <id>
```

### Don't waste time waiting for CI for fast things
- Format code `nix fmt -- (jj file list)`

### Don't waste limited local resources for slow things
- Let CI handle big builds and simply monitor the PR's CI jobs for results
