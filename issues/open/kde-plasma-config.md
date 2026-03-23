# Declarative KDE Plasma Configuration

**Labels**: desktop
**Related**: lib/modules/nixos/plasma.nix

KDE Plasma settings (shortcuts, themes, panels, window rules, etc.)
are not managed declaratively. Changes made in the KDE Settings UI are ephemeral
and not reproducible across hosts.

[plasma-manager](https://github.com/pjones/plasma-manager) exists but **requires
home-manager**, which was removed from this config.

## Alternatives without home-manager

1. **`environment.etc."xdg/..."`** for system-wide defaults — already used for
   `kwinrc` in `plasma.nix`. KDE reads `/etc/xdg/` as fallback. Simplest option.
2. **`lyte.userFiles`** to write KDE config files directly to `~/.config/`.
   Full declarative control but overwrites entire files (no merge with UI changes).
3. **Port plasma-manager's `write_config.py`** (~300 lines, pure Python) into a
   `system.userActivationScripts` entry for key-level merging without home-manager.

## Key KDE config files

`kdeglobals`, `kwinrc`, `kwinrulesrc`, `plasmashellrc`, `plasmarc`,
`kglobalshortcutsrc`, `khotkeysrc`, `kcminputrc`, `kscreenlockerrc`,
`krunnerrc`, `powerdevilrc`, `kxkbrc`, `dolphinrc`, `katerc`, `klipperrc`,
`baloofilerc`, `ksmserverrc`, `ksplashrc`, `plasma-localerc`, `plasmanotifyrc`

All are INI-format files under `~/.config/`. plasma-manager also ships `rc2nix`
which reads existing KDE config and generates Nix expressions — useful for
bootstrapping even without using plasma-manager itself.

## Recommendation

Options 1+2 are likely sufficient. The merge approach (option 3) is only needed
if mixing declarative keys with user-tweakable KDE Settings UI changes. On
fully-controlled hosts (steamdecks), overwriting is fine.
