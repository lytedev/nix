This document outlines issues I currently have with my setup.

In Helix, hit `<SPACE>s` to list headings.

# Forgejo using CPU doing nothing

**Problem**: Forgejo sits at 50% CPU when idle.

Seems like 16 runners just hitting the server causes CPU to hover around 50% (of
one thread). Is this just password/token hashing algos cranking?

# SSO

**Problem**: I would love for Jellyfin, Audiobookshelf, Samba shares, etc. to
all use a single authentication/authorization mechanism for the whole family.

Kanidm is fully setup, but not integrated with anything.

Perhaps the SpacetimeDB instance would be a good starting point? Just need JWTs?

Kanidm 1.9 introduces native HJSON-based entry migrations (`migration_path`),
replacing the broken NixOS provision module and the need for oddlama/kanidm-provision.
A custom `kanidm-migrations` NixOS module generates the migration files from Nix config.

## Kanidm Alternatives

Currently, I'm too ignorant to pretend to know why I might want to swap, but
just in case:

- Authelia
- authentik (has some recent CVEs? sign of bad code or of good white hats?)
- ZITADEL
- Keycloak
- Ory

I definitely want to avoid anything JVM-related due to my own inexperience and
negative predispositions, which I believe excludes keycloak

# Automated GitHub Mirroring

**Problem**: My projects are not all mirrored to GitHub.

I think the current, manually-specified key expires every so often and I'm not
sure I have a way to know when I fall behind? Perhaps a very simple val.town
script could handle setting up a new key and updating? But how would the val
have a key?

> Who watches the watchers?

# Desktop notifications for `ghostty` long commands

**Problem**: Long-running terminal commands that I cannot see have no way of
letting me know they have finished without me explicitly setting up the command
with `notify-send` or some equivalent.

**Related**: https://github.com/ghostty-org/ghostty/discussions/3555

# Huge OS Footprint

**Problem**: Every `nixpkgs` update requires ~32GB of downloads from the cache.
Installations on disk even with a minimal configuration take many GB, which is
problematic as one of my current deployments goes to a 16GB disk.

In general, I want to remain space-conscious (or at least
space-debugging-conscious).

# Tailscale Dependency

**Problem**: Tailscale is somewhat of a single-point-of-failure for remote
access at the moment.

I want to either:

- Ensure LAN ssh access
  - I believe this is currently working with the router configured to allow
    SSH even without Tailscale. That in combination with DDNS means I have two
    access points. My single point of failure is gone!
- Ensure a self-hosted VPN is _also_ an option
  - Setup Headscale in addition to Tailscale?

# Declarative KDE Plasma Configuration

**Problem**: KDE Plasma settings (shortcuts, themes, panels, window rules, etc.)
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

# Syncthing ROM Syncing

**Problem**: Steamdeck and beefcake have emulator ROM directories that should be
synced via Syncthing, but the current setup is unclear.

Beefcake runs syncthing as a dedicated `syncthing` user at `/storage/syncthing`
with its own separate config (not using the shared `lyte.syncthing` module).
Steamdecks are currently offline and couldn't be inspected.

## TODO

- Turn on steamdeck and inspect ROM directory structure
- Check beefcake's syncthing folder config (need root or syncthing user access)
- Add a `roms` folder to the shared syncthing module (or a host-specific folder override)
- Decide whether beefcake should use the shared module or keep its server-specific setup
- Wire up steamdeck(s) with `lyte.syncthing.enable` and sops keys

# macOS+Nix

determinate nix should make this relatively straightforward
not sure how it will play with the corporate controlware

# Remote Desktop

**Problem**: From anywhere on any of my devices I should be able to remote into
an existing (or at least usable) graphical session.

Should be possible with KDE/Plasma (KRDC/KRFB) or other tools. Can
the setup get baked into Nix or must it be done manually?
