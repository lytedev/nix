#!/usr/bin/env bash
# The tier-0 deploy gate: assert the beefcake-lite VM boots and CONVERGES.
#
# "Converged" used to mean strictly `is-system-running == running` (zero failed
# units). That false-positived (2026-07-09, #729 — a trivial config-only deploy
# was BLOCKED): a handful of production services provably CANNOT converge in a
# stateless, single-boot lite VM even though they are perfectly healthy on the
# real host, because they need a reachable Kanidm, persisted state, certs, or a
# backup target the lite tier has no way to provide. Failing on those is noise.
#
# So the gate now tolerates a `degraded` state IFF every failed unit is a KNOWN
# stateless-incompatible one, while staying strict about everything the gate
# actually exists to catch (systemd/dbus/boot-graph regressions & the
# cross-release live-switch wedge):
#   - boot must reach a terminal state (running|degraded), not hang/wedge
#   - no stuck start jobs (nothing wedged mid-activation)
#   - NO failed unit outside the allowlist (a real regression fails the gate)
#   - allowlisted-failed units must still be config-valid (LoadState=loaded) —
#     a broken unit file / eval regression cannot hide behind the allowlist
#   - a CORE set of services must be positively ACTIVE — catches the "inactive,
#     not failed" wedge signature that a bare --failed sweep misses
#
# Usage: bash lite/assert-green.sh [ssh-port]   (default 2300)
set -euo pipefail
port="${1:-2300}"
key="${XDG_CACHE_HOME:-$HOME/.cache}/beefcake-lite/ssh-key"
S() {
  timeout 25 ssh -q -p "$port" -i "$key" -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost "$@"
}

# Units known to require production state/secrets/peers absent from a stateless
# lite boot. Healthy on the live host; their failure here is expected & benign.
# Keep this list TIGHT and documented — every entry is a hole in the gate.
ALLOW_NONCONVERGE=(
  kanidm-oauth2-secrets.service # fetches OAuth2 client secrets from a reachable Kanidm (none in lite)
  home-assistant.service        # needs persisted HA state/config, not present on a fresh boot
  mosquitto.service             # needs MQTT certs/state not provisioned in the stateless tier
  backup-vaultwarden.service    # backup oneshot; no backup target in lite (inactive between runs live)
)
# Services the lite tier IS expected to bring up. Asserted positively so a
# regression that leaves one INACTIVE (not failed) still trips the gate. Kept
# to peer-independent essentials that tier-0 has always converged (edge, DNS,
# DB, git); the longer service tail is advisory (covered by the no-unexpected-
# failure check above).
CORE_ACTIVE=(
  caddy.service
  knot.service
  postgresql.service
  forgejo.service
)

echo "== waiting for ssh =="
for _ in $(seq 60); do S true 2>/dev/null && break; sleep 10; done
S true 2>/dev/null || { echo "FAIL: ssh never came up"; exit 1; }

echo "== waiting for boot to converge (up to 20 min; first boot does migrations + k3s airgap import) =="
state=starting
for _ in $(seq 120); do
  # NB: is-system-running exits non-zero for any state != running, so a
  # `|| echo` fallback would DOUBLE the output ("starting\nunreachable").
  # Capture stdout regardless of exit code; empty means ssh never delivered.
  # `|| true`: is-system-running exits non-zero while starting/degraded, and
  # under set -e a failing command substitution in an assignment KILLS the
  # script mid-loop (silently — learned from a receipt run that died here).
  state=$(S systemctl is-system-running 2>/dev/null | head -1 || true)
  [ -z "$state" ] && state=unreachable
  # unreachable = ssh timeout while the box is pegged — keep waiting
  case "$state" in starting|unreachable) ;; *) break ;; esac
  sleep 10
done

jobs=$(S 'systemctl list-jobs --no-legend | wc -l' || echo 999)
running=$(S 'systemctl list-units --type=service --state=running --no-legend | wc -l' || echo 0)
mapfile -t failed_units < <(S 'systemctl list-units --state=failed --no-legend --plain' 2>/dev/null | awk '{print $1}' | grep . || true)

echo "state=$state stuck-jobs=$jobs running-services=$running failed=${#failed_units[@]} (${failed_units[*]:-none})"

fail() {
  echo "FAIL: $*"
  S 'systemctl list-units --state=failed --no-legend --plain | head -15' || true
  S 'systemctl list-jobs --no-legend | head -10' || true
  exit 1
}

# 1. No stuck start jobs — a wedged activation never settles.
[ "$jobs" -eq 0 ] || fail "stuck start jobs ($jobs) — boot did not settle (possible wedge)"

# 2. Boot must have reached a terminal state.
case "$state" in
  running) echo "PASS: tier-0 all-green — the production configuration is viable"; exit 0 ;;
  degraded) : ;; # fall through to the tolerated-failure checks
  *) fail "system state '$state' is neither running nor degraded — hang/wedge" ;;
esac

# --- degraded: only tolerable if it is EXACTLY the expected stateless holes ---
in_allow() { local u; for u in "${ALLOW_NONCONVERGE[@]}"; do [ "$u" = "$1" ] && return 0; done; return 1; }

# 3. Every failed unit must be allowlisted — anything else is a real regression.
unexpected=()
for u in "${failed_units[@]}"; do in_allow "$u" || unexpected+=("$u"); done
[ ${#unexpected[@]} -eq 0 ] || fail "unexpected failed unit(s), not in the stateless allowlist: ${unexpected[*]}"

# 4. Allowlisted failures must be RUNTIME failures, not config/eval breakage:
#    the unit still has to load. LoadState!=loaded means a regression broke the
#    unit itself, which the allowlist must NOT mask.
for u in "${failed_units[@]}"; do
  ls=$(S "systemctl show -p LoadState --value $u" 2>/dev/null | head -1 || true)
  [ "$ls" = loaded ] || fail "allowlisted unit $u has LoadState=$ls (config regression, not runtime non-converge)"
done

# 5. Core services must be positively ACTIVE (inactive-not-failed guard).
inactive_core=()
for u in "${CORE_ACTIVE[@]}"; do
  st=$(S "systemctl is-active $u" 2>/dev/null | head -1 || true)
  [ "$st" = active ] || inactive_core+=("$u=${st:-unknown}")
done
[ ${#inactive_core[@]} -eq 0 ] || fail "core service(s) not active: ${inactive_core[*]}"

echo "PASS: degraded, but only the expected stateless-incompatible units failed"
echo "      (${failed_units[*]}) — all config-valid; core services active; no stuck jobs;"
echo "      no unexpected failures. Production config is viable; the tolerated units are"
echo "      validated on the live host, not in this tier."
exit 0
