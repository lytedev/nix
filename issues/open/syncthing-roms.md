# Syncthing ROM Syncing

**Labels**: service, beefcake, steamdeck

Steamdeck and beefcake have emulator ROM directories that should be
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
