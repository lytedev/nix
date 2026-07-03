#!/usr/bin/env bash
# The tier-0 gate: assert the beefcake-lite VM converges to ALL-GREEN.
# Success criteria (the "production config is viable" proof):
#   - systemctl is-system-running == running  (implies zero failed units)
#   - no lingering start jobs (nothing stuck activating)
# Usage: bash lite/assert-green.sh [ssh-port]   (default 2300)
set -euo pipefail
port="${1:-2300}"
key="${XDG_CACHE_HOME:-$HOME/.cache}/beefcake-lite/ssh-key"
S() {
  timeout 25 ssh -q -p "$port" -i "$key" -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost "$@"
}

echo "== waiting for ssh =="
for _ in $(seq 60); do S true 2>/dev/null && break; sleep 10; done
S true 2>/dev/null || { echo "FAIL: ssh never came up"; exit 1; }

echo "== waiting for boot to converge (up to 20 min; first boot does migrations + k3s airgap import) =="
state=starting
for _ in $(seq 120); do
  # NB: is-system-running exits non-zero for any state != running, so a
  # `|| echo` fallback would DOUBLE the output ("starting\nunreachable").
  # Capture stdout regardless of exit code; empty means ssh never delivered.
  state=$(S systemctl is-system-running 2>/dev/null | head -1)
  [ -z "$state" ] && state=unreachable
  # unreachable = ssh timeout while the box is pegged — keep waiting
  case "$state" in starting|unreachable) ;; *) break ;; esac
  sleep 10
done

jobs=$(S 'systemctl list-jobs --no-legend | wc -l')
failed=$(S 'systemctl list-units --state=failed --no-legend | wc -l')
running=$(S 'systemctl list-units --type=service --state=running --no-legend | wc -l')

echo "state=$state failed=$failed stuck-jobs=$jobs running-services=$running"
if [ "$state" = running ] && [ "$jobs" -eq 0 ]; then
  echo "PASS: tier-0 all-green — the production configuration is viable"
  exit 0
fi
echo "FAIL: not converged"
S 'systemctl list-units --state=failed --no-legend --plain | head -15'
S 'systemctl list-jobs --no-legend | head -10'
exit 1
