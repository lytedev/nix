# Internal Usage

## Update Server

**NOTE**: I want to establish a solid way to do this without `root@`.

**TODO**: This could easily be wrapped up in a `nix run github:lytedev/nix#install` or something with fuzzy-finders for the variable options.

**TODO**: could also probably get some helpers baked into an ISO?

```fish
g a; set host beefcake; nix run nixpkgs#nixos-rebuild -- --flake ".#$host" \
  --target-host "root@$host" --build-host "root@$host" \
  switch --show-trace
```

## Safer Method

```bash
# make sure all files are at least staged so nix flakes will see them
git add -A

# initialize a delayed reboot by a process you can kill later if things look good
# note that the amount of time you give it probably needs to be enough time to both complete the upgrade
# _and_ perform whatever testing you need
host=your_host
ssh -t "root@$host" "bash -c '
  set -m
  # sleep 30 mins
  (sleep 1800; reboot;) &
  jobs -p
  bg
  disown
'"

# build the system and start running it, but do NOT set the machine up to boot to that system yet
# we will test things and make sure it works first
# if it fails, the reboot we started previously will automatically kick in once the timeout is reached
# and the machine will boot to the now-previous iteration
nix run nixpkgs#nixos-rebuild -- --flake ".#$host" \
  --target-host "root@$host" --build-host "root@$host" \
  test --show-trace

# however you like, verify the system is running as expected
# if it is, run the same command with "switch" instead of "test"
# otherwise, we will wait until the machine reboots back into the 
# this is crude, but should be pretty foolproof
# the main gotcha is that the system is already unbootable or non-workable, but
# if you always use this method, that should be an impossible state to get into

# if we still have ssh access and the machine fails testing, just rollback
# instead of waiting for the reboot
ssh "root@$host" nixos-rebuild --rollback switch
```

## Provisioning New NixOS Hosts

Note that for best results the target flake attribute should first be built and
cached to the binary cache at `nix.h.lyte.dev`.

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

# disk encryption key (if needed)
echo -n "password" > /tmp/secret.key

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
    --no-write-lock-file \
    --flake 'git+https://git.lyte.dev/lytedev/nix#${FLAKE_ATTR}' \
    --option trusted-substituters 'https://cache.nixos.org https://nix.h.lyte.dev' \
    --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0='"
```

Then:

1. Tailscale connection and roles.

2. Setup/copy any GPG/SSH keys.

```shell
# from a machine with the key
$ gpg --export-secret-key --armor daniel@lyte.dev | ssh $host "umask 077; cat - > p.key"
$ rsync -r ~/.ssh $host:~/.ssh

# on the target machine
$ gpg --import ~/p.key && rm ~/p.key
$ gpg --edit-key daniel@lyte.dev # trust ultimately
```

3. Setup/copy any password stores.

```shell
$ rsync -r ~/.local/share/password-store $host:~/.local/share/password-store
```

4. Firefox sync configured.

# Temporary Firewall Changes

Source: https://discourse.nixos.org/t/how-to-temporarily-open-a-tcp-port-in-nixos/12306/2
