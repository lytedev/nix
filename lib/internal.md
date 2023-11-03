# Internal Usage

## Update Server

```shell
g a; set host beefcake; nix run nixpkgs#nixos-rebuild -- --flake ".#$host" \
  --target-host "root@$host" --build-host "root@$host" \
  switch --show-trace
```
