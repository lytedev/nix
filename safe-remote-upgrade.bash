#!/usr/bin/env bash

usage() {
  echo 'safe-remote-upgrade.bash $flake $target_host'
}

error() {
  echo "error: $1"
  usage
}

if [[ -z $1 ]]; then
  echo "error: no flake specified"
  usage
  exit 1
fi
flake="$1"; shift

if [[ -z $1 ]]; then
  echo "error: no target host specified"
  usage
  exit 1
fi
target_host="$1"; shift

git add -A

ssh "root@$target_host" "bash -c '
  set -m
  # sleep 5 mins
  (sleep 300; reboot;) &
  jobs -p
  bg
  disown
'"

nix run nixpkgs#nixos-rebuild -- --flake "$flake" \
  --target-host "root@$target_host" test --show-trace

echo "Upgrade ready for verification. If you still have SSH access you can bail out without waiting with the following command:"
echo "  ssh 'root@$target_host' nixos-rebuild --rollback switch"
echo
echo 'Done!'

