# Documentation

## Internal Setup

If you're deploying anything secrets-related, you will need the proper keys:

```shell_session
$ mkdir -p ${XDG_CONFIG_HOME:-~/.config}/sops/age
$ pass age-key >> ${XDG_CONFIG_HOME:-~/.config}/sops/age/keys.txt
```

# Update Remote Hosts

```shell
$ , deploy .
```

# Provisioning New NixOS Hosts

```shell
nix run --extra-experimental-features 'nix-command flakes' \
  --accept-flake-config git+https://git.lyte.dev/lytedev/nix#installer
```

Or you can install manually with the process below:

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
    --arg disk '\"/dev/${DISK}\"'"

# install
nix-shell --packages git \
  --run "sudo nixos-install \
    --no-write-lock-file \
    --flake 'git+https://git.lyte.dev/lytedev/nix#${FLAKE_ATTR}' \
    --option trusted-substituters 'https://cache.nixos.org https://nix.h.lyte.dev' \
    --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0='"
```

### Post-Installation Setup

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

```shell
$ nixos-firewall-tool --help
```

Or if we're performing ad-hoc operations on the router's nftables rules as root:

```shell
# add a rule
$ nft add rule ...

# find a rule
$ nft -a list table $table
# examples:
$ nft -a list table nat
$ nft -a list table filter
$ nft -a list table ip

# delete a rule
$ nft delete rule $table $chain handle $handle
```
