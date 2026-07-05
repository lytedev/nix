#!/usr/bin/env bash
# Deploy-gate orchestrator: prove a candidate beefcake closure is viable
# BEFORE it touches production. Self-contained: build beefcake-lite from the
# current tree, boot it fresh (own state dir + ssh port, so it never collides
# with a manually-running lite VM on :2300), run the all-green gate, tear
# down. Exit 0 = viable; exit 1 = the candidate would break.
#
#   LYTE_VALIDATE=full   (default) build + fresh boot + assert-green (~20 min
#                        first time, faster warm)
#   LYTE_VALIDATE=build  build only — still catches eval errors, sops
#                        manifest/secret-shape breaks, missing packages (~min)
#
# Used by lib/deploy/guard-wrapper.nix for beefcake targets; runnable by hand.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${LYTE_VALIDATE:-full}"
port="${LITE_GATE_PORT:-2301}"
state="${LITE_GATE_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/beefcake-lite-gate}"

echo "== deploy-gate: building beefcake-lite from the current tree =="
bash lite/run-lite.sh build

if [ "$mode" = build ]; then
  echo "PASS (build-level): candidate evaluates and builds; boot not exercised (LYTE_VALIDATE=build)"
  exit 0
fi

echo "== deploy-gate: fresh boot (port $port, state $state) =="
rm -rf "$state"
mkdir -p "$state"
install -m 600 keys/demo-ssh-key "$state/ssh-key"

runner=$(ls result-lite/bin/run-*-vm | head -1)
vm_pid=""
cleanup() {
  if [ -n "$vm_pid" ] && kill -0 "$vm_pid" 2>/dev/null; then
    kill "$vm_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

(
  cd "$state"
  export NIX_DISK_IMAGE="$state/gate.qcow2"
  export QEMU_NET_OPTS="restrict=on,hostfwd=tcp::${port}-:22"
  exec "$runner"
) > "$state/console.log" 2>&1 &
vm_pid=$!

# assert-green reads the key from the beefcake-lite cache dir by default;
# point it at ours.
mkdir -p "$state/xdg/beefcake-lite"
cp "$state/ssh-key" "$state/xdg/beefcake-lite/ssh-key"
if XDG_CACHE_HOME="$state/xdg" bash lite/assert-green.sh "$port"; then
  echo "== deploy-gate: PASS — candidate closure is viable =="
  exit 0
fi
echo "== deploy-gate: FAIL — candidate closure did NOT converge all-green =="
echo "   (console: $state/console.log; VM already torn down)"
exit 1
