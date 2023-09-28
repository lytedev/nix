# Nix

My grand, declarative, and unified application, service, environment, and
machine configuration, secret, and package management in a single flake. ❤️ ❄️

**NOTE**: Everything in here is highly specific to my personal preference. I
can't recommend you actually use this in any way, but hopefully some stuff in
here is useful inspiration.

# Quick Start

You don't have even have to clone this crap yourself. How cool is that!

But if you're gonna change stuff you had better setup the pre-commit hook:

```shell_session
ln -s $PWD/pre-commit.bash .git/hooks/pre-commit
```

## NixOS

```shell_session
nixos-rebuild --flake git+https://git.lyte.dev/lytedev/nix switch
```

## Not NixOS

```shell_session
$ curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
$ nix profile install github:nix-community/home-manager
$ home-manager switch --flake git+https://git.lyte.dev/lytedev/nix
```

# Advanced Usage

## Push NixOS Config

```bash
nix run nixpkgs#nixos-rebuild -- --flake 'git+https://git.lyte.dev/lytedev/nix#host' \
  --target-host root@host --build-host root@host \
  switch --show-trace
```

### Safer Method

```bash
# initialize a delayed reboot by a process you can kill later if things look good
# note that the amount of time you give it probably needs to be enough time to both complete the upgrade
# _and_ perform whatever testing you need
ssh -t root@host "bash -c '
  set -m
  (sleep 300; reboot;) &
  jobs -p
  bg
  disown
'"

# build the system and start running it, but do NOT set the machine up to boot to that system yet
# we will test things and make sure it works first
# if it fails, the reboot we started previously will automatically kick in once the timeout is reached
# and the machine will boot to the now-previous iteration
nix run nixpkgs#nixos-rebuild -- --flake 'git+https://git.lyte.dev/lytedev/nix#host' \
  --target-host root@host --build-host root@host \
  test --show-trace

# however you like, verify the system is running as expected
# if it is, run the same command with "switch" instead of "test"
# otherwise, we will wait until the machine reboots back into the 
# this is crude, but should be pretty foolproof
# the main gotcha is that the system is already unbootable or non-workable, but
# if you always use this method, that should be an impossible state to get into

# if we still have ssh access and the machine fails testing, just rollback
# instead of waiting for the reboot
# TODO: this is not tested yet
ssh root@beefcake nixos-rebuild --rollback switch
```

## Provisioning New NixOS Hosts

<!-- TODO: Installation from a live ISO does not fully work yet -->

```bash
# establish network access
# plug in ethernet or do the wpa_cli song and dance for wifi
wpa_cli scan
wpa_cli scan_results
wpa_cli add_network 0
wpa_cli set_network 0 ssid "MY_SSID"
wpa_cli set_network 0 psk "MY_WIFI_PASSWORD"
wpa_cli enable_network 0
wpa_cli save_config

# partition disks
nix-shell --packages git --run "sudo nix run \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes \
  github:nix-community/disko -- \
    --flake 'git+https://git.lyte.dev/lytedev/nix#${PARTITION_SCHEME}' \
    --mode disko \
    --arg disks '[ \"/dev/${DISK}\" ]'"

# install
nix-shell --packages git \
  --run "sudo nixos-install \
    --flake 'git+https://git.lyte.dev/lytedev/nix#${FLAKE_ATTR}' \
    --option substituters 'https://nix.h.lyte.dev' \
    --option trusted-public-keys 'h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0='"
```

# To Do

- Port configuration (lytedev/dotfiles) to home manager where applicable?
  - Sway and Kitty come to mind
  - macOS options?
- I don't understand Nix well enough to know why stuff is being compiled even when I have a binary cache
  - Maybe it detects different CPUs and will recompile certain packages for per-CPU optimizations?
    - How does this factor in with "pureness"?
- Custom pre-configured live ISO
- Unify standalone home manager module with NixOS home manager module?
