#!/usr/bin/env bash
# Build (and optionally run) beefcake-lite: the real beefcake config
# extended with lite/beefcake-lite.nix, from THIS workspace's flake.
#
#   bash lite/run-lite.sh build   # just build the VM runner
#   bash lite/run-lite.sh run     # build + boot (egress-cut usernet,
#                                 # ssh on localhost:2300)
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$(cd ../.. && pwd)

expr="
  let
    flake = builtins.getFlake \"path:$repo\";
    lite = flake.nixosConfigurations.beefcake.extendModules {
      modules = [ $PWD/lite/beefcake-lite.nix ];
    };
  in
  lite.config.system.build.vm
"

echo "== building beefcake-lite VM (real beefcake closure; first build is big) =="
nix build --impure --expr "$expr" -o result-lite
echo "== built: result-lite =="

if [ "${1:-build}" = run ]; then
  state="${XDG_CACHE_HOME:-$HOME/.cache}/beefcake-lite"
  mkdir -p "$state"
  cd "$state"
  install -m 600 "$OLDPWD/keys/demo-ssh-key" ssh-key
  export NIX_DISK_IMAGE="$state/beefcake-lite.qcow2"
  # restrict=on: TOTAL egress cut (validation-tier semantics) — only the
  # hostfwds work. ssh: localhost:2300.
  export QEMU_NET_OPTS="restrict=on,hostfwd=tcp::2300-:22"
  runner=$(ls "$OLDPWD"/result-lite/bin/run-*-vm | head -1)
  echo "== booting; ssh -p 2300 -i $state/ssh-key root@localhost =="
  exec "$runner"
fi
