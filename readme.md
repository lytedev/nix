# Nix

The grand unification of configuration.

## Not on NixOS?

Install Nix using Determinate Systems's installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

And [install Home Manager in standalone mode](https://nix-community.github.io/home-manager/index.html#sec-install-standalone):

# NixOS

```bash
nixos-rebuild --flake git+https://git.lyte.dev/lytedev/nix switch
```

## Remotely

```bash
nixos-rebuild --flake git+https://git.lyte.dev/lytedev/nix#host \
  --target-host root@host --build-host root@host \
  switch
```

# Home Manager

This can be used on non-NixOS hosts:

```bash
home-manager switch --flake .#daniel
```

## Remotely

```bash
ssh daniel@host 'home-manager switch --flake git+https://git.lyte.dev/lytedev/nix#daniel'
```

# Provisioning New NixOS Hosts

Documented below is my process for standing up a new NixOS node configured and
managed by this flake from scratch.

## Network Access

Boot a NixOS ISO and establish network access:

```bash
# plug in ethernet or do the wpa_cli song and dance for wifi access
wpa_cli scan # if you need to
wpa_cli scan_results

wpa_cli add_network 0
wpa_cli set_network 0 ssid "MY_SSID"
wpa_cli set_network 0 psk "MY_WIFI_PASSWORD"
wpa_cli enable_network 0
wpa_cli save_config
```

Partition disk(s) and mount up however you like. Preferably, though, use a
[disko configuration](./disko.nix) from this flake like so:

```bash
# TODO: I'm relatively certain this can be simplified to a single `nix run` command
sudo nix-shell --packages git --run "nix run \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes \
  github:nix-community/disko -- \
    --flake 'git+https://git.lyte.dev/lytedev/nix#standard' \
    --mode disko \
    --arg disks '[ \"/dev/your_disk\" ]'"
```

And finally install NixOS as specified by this flake:

```bash
nix-shell --packages git \
  --run "sudo nixos-install \
    --flake 'git+https://git.lyte.dev/lytedev/nix#yourNixosConfig'"
```

**NOTE**: This takes a while, mostly due to building Helix myself on each box. I
really need to figure out a good local caching setup.

**NOTE**: since the disko setup _should_ be included in the nixosConfiguration,
I would like to know how to do this all in one go -- maybe even building my own
live media?

# Other To Dos

- Local Nix substitute/cache setup?
- Port configuration (lytedev/dotfiles) to home manager where applicable?
- Pre-commit checks with `nix flake check`?
