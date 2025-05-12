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

Declarative provisioning with the builtin nixos did not work for me, but I may
still be able to leverage https://github.com/oddlama/kanidm-provision on its
own.

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

# GNOME 48

[Why?](https://release.gnome.org/48/)

- HDR!
- Global shortcuts!
- Notification stacking!
- Performance improvements, especially dynamic triple-buffering for some of the
  thinkpads and the TV PC.
- Image viewer can do simple edits, a small speedup when cropping nonsense off
  kids' coloring pages.
- Try out their new main font?

- `nixpkgs` PR: https://github.com/NixOS/nixpkgs/pull/386514
- release notes: https://release.gnome.org/48/

# macOS+Nix

determinate nix should make this relatively straightforward
not sure how it will play with the corporate controlware

# Remote Desktop

**Problem**: From anywhere on any of my devices I should be able to remote into
an existing (or at least usable) graphical session.

Should be possible with "raw" GNOME, I think it just requires some setup. Can
the setup get baked into Nix or must it be done manually?
