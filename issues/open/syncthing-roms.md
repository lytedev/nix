# Syncthing ROM Syncing

**Labels**: service, beefcake, steamdeck
**Related**: lib/modules/nixos/roms.nix, packages/hosts/beefcake/roms.nix

## Miyoo Mini — done

ROM and save sync via rsync over SSH is working. Dedicated `miyoo-sync` user
with restricted rrsync access. Supports OnionOS folder structure (GBA, SFC, GB,
GBC, MD, etc.) at `/storage/miyoo-mini/`.

## Steamdeck — not done

Steamdeck ROM syncing via Syncthing is still unimplemented.
`lib/modules/nixos/steamdeck.nix` has a TODO for this.

### Remaining work

- Turn on steamdeck and inspect ROM directory structure
- Add a `roms` syncthing folder for steamdeck(s)
- Wire up steamdeck(s) with `lyte.syncthing.enable` and sops keys
