# zomg nixos

TODO: overhaul this readme

```bash
$ ssh -t beefcake 'cdd && pwd && g pl && cd os/linux/nix && sudo nixos-rebuild switch --flake .# && echo DONE'
```

Or for pushing:

```bash
# do once to setup
$ ssh -t beefcake 'cdd && git config receive.denyCurrentBranch updateInstead'

# probably regenerate and commit flake.lock from this directory
nix flake lock

# push and rebuild+switch
$ git push beefcake:~/.config/lytedev-dotfiles
$ ssh -t beefcake 'cd ~/.config/lytedev-dotfiles/os/linux/nix && sudo nixos-rebuild switch --flake .# && echo DONE'
```

# Install For Home Manager

<!-- TODO: document nix+home manager installation for arch boxes -->

```bash
home-manager switch --flake .#daniel
```

# Install From NixOS Bootable Media

Documented below is my process for standing up a new NixOS node configured and
managed by this flake.

## Network Access

Boot the ISO (via Ventoy USB drive) and establish network access:

```bash
# plug in ethernet or do the wpa_cli song and dance
# scan if needed
wpa_cli scan
wpa_cli scan_results

wpa_cli add_network 0
wpa_cli set_network 0 ssid "MY_SSID"
wpa_cli set_network 0 psk "MY_WIFI_PASSWORD"
wpa_cli enable_network 0
wpa_cli save_config
```

Partition and mount disk(s) however you like. Preferably, though, use a disko
configuration from this flake like so:

```bash
sudo nix-shell --packages git --run "
  nix run \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    github:nix-community/disko -- \
      --flake 'git+https://git.lyte.dev/lytedev/nix#diskoConfigOfChoice' \
      --mode disko \
      --arg disks '[ \"/dev/your_disk\" ]'
"
```

And finally install NixOS as specified by this flake:

```bash
nix-shell --packages git \
  --run "
    sudo nixos-install \
      --flake 'git+https://git.lyte.dev/lytedev/nix#yourNixosConfig'
  "
```

**NOTE**: This takes a while, mostly due to building Helix myself on each box. I
really need to figure out a good local caching setup.

# Ops stuff

- **TODO**: Look into https://github.com/zhaofengli/colmena

# Other To Dos

- **TODO**: check stuff during receive with a hook?
