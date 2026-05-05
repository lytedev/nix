# Steam: nix-managed → flatpak

Moves a host from the nixpkgs Steam (`programs.steam.enable = true`) to the
flathub Steam (`com.valvesoftware.Steam`).

## Why

- Sandboxed; doesn't depend on the nixpkgs `programs.steam` machinery, the
  `gaming.nix` module, or the wine/lutris/openldap chain that comes with it.
- Updates roll independently of the host's NixOS rebuild cadence.
- Aligns with how the rest of the GUI app surface on these hosts is managed
  (most non-system apps are flathub).

## Status by host

`dragon` is the reference: already on flatpak, with `programs.steam.enable`
commented out in its host file. Use it as the template for the others.

| Host        | Pre-migration             | Library size | Notes                                 |
| ----------- | ------------------------- | ------------ | ------------------------------------- |
| `dragon`    | already flatpak           | n/a          | reference                             |
| `foxtrot`   | nixpkgs Steam, library at `~/.local/share/Steam` | check `du -sh ~/.local/share/Steam` | Framework 13; mobile, expect smaller library |
| `bigtower`  | nixpkgs Steam + lutris    | check        | desktop, may have extra library folders on secondary drives |
| `flipflop`  | nixpkgs Steam (Thinkpad)  | likely small | rarely used for gaming                |
| `flipflop2` | nixpkgs Steam (Thinkpad)  | likely small | rarely used for gaming                |
| `htpifour`  | nixpkgs Steam, `remotePlay.openFirewall = true` | check | HTPC; if you actually use Remote Play, re-open the ports manually (see below) |
| `generic`   | template; no live host    | n/a          | nothing to migrate                    |

Run `du -sh ~/.local/share/Steam` and `df -h ~/.local/share/Steam` on each
live host before starting — the migration approach depends on free space and
library size.

## Path mapping

```
nix-managed:  ~/.local/share/Steam/
flatpak:      ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/
```

Inside `Steam/`, the relevant subdirectories are the same in both layouts:

- `steamapps/` — installed games (`common/`, `<appid>.acf`, `workshop/`)
- `steamapps/compatdata/` — Proton prefixes (per-game wine state)
- `userdata/<steamid>/` — per-game local settings, screenshots, non-cloud
  saves
- `config/` — login token, friends list, library tabs

## Migration

Pick one approach based on library size and bandwidth. Do this with Steam
**not running** in either flavor.

### Approach A — move the directory (preserves installs)

Best if the library is large or the connection is slow. Halts in-progress
downloads; you'll need to relaunch them.

```bash
# 1. Confirm Steam (nix) is fully closed
pgrep -af steam | grep -v grep   # should be empty

# 2. Install flatpak Steam but don't launch yet
flatpak install -y flathub com.valvesoftware.Steam

# 3. Move the library into the flatpak data dir
mkdir -p ~/.var/app/com.valvesoftware.Steam/.local/share
mv ~/.local/share/Steam ~/.var/app/com.valvesoftware.Steam/.local/share/Steam

# 4. Launch flatpak Steam — it will re-detect installed games
flatpak run com.valvesoftware.Steam
```

Steam may want to "verify" each game on first launch; that's a quick hash
check, not a redownload.

### Approach B — additional library folder (no move)

Leave `~/.local/share/Steam` in place and have flatpak Steam treat it as an
additional library folder. Useful if the library lives on a secondary disk
already mounted somewhere flatpak can't reach by default.

```bash
flatpak install -y flathub com.valvesoftware.Steam

# Grant access to the existing library path
flatpak override --user --filesystem="$HOME/.local/share/Steam" com.valvesoftware.Steam

# (or, if your library lives on another drive)
flatpak override --user --filesystem=/mnt/games com.valvesoftware.Steam

flatpak run com.valvesoftware.Steam
# Steam → Settings → Storage → "+" → add the path as a library folder
```

This leaves you running two Steam logins/configs side by side. Once you're
confident the flatpak side works, you can `flatpak run com.valvesoftware.Steam`
permanently and ignore the old install.

### Approach C — reinstall

Smallest hands-on time if you trust Steam Cloud for saves and have the
bandwidth to redownload. Skips compatdata and any non-cloud save games — verify
those per-game first if it matters.

```bash
flatpak install -y flathub com.valvesoftware.Steam
flatpak run com.valvesoftware.Steam
# Sign in, redownload games as needed.

# Once verified everything you care about restored:
rm -rf ~/.local/share/Steam
```

## Per-host gotchas

- **`htpifour`**: dropped `programs.steam.remotePlay.openFirewall = true`.
  If you actually use Remote Play on the HTPC, add explicit firewall rules
  back in the host file:

  ```nix
  networking.firewall = {
    allowedTCPPortRanges = [ { from = 27036; to = 27037; } ];
    allowedUDPPortRanges = [ { from = 27031; to = 27036; } ];
  };
  ```

- **`bigtower`**: also had `lutris` in `environment.systemPackages`. Reinstall
  via flathub if you still want it: `flatpak install flathub net.lutris.Lutris`.
  `wine` and `winetricks` similarly: `org.winehq.Wine`, `com.usebottles.bottles`.

- **Extra library folders on other drives**: any path outside `$HOME` needs an
  explicit `flatpak override --user --filesystem=...` before Steam can see it.

## Cleanup after migration

Once the host is on flatpak Steam and verified working:

- Old library remains at `~/.local/share/Steam` if you used Approach B —
  delete when ready.
- The `programs.steam.*` config in the host file is already removed by this
  PR; nothing to do on the nix side.
- `nix-collect-garbage -d` on next rebuild will prune the old wine/lutris/
  proton store paths.
