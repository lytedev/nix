#!/usr/bin/env bash
#
# Idle blank/unblank for ONLY the Steam Deck's built-in panel backlight.
#
# Invoked by steamdeck-internal-idle (swayidle) on session idle/resume. When
# docked we do nothing: the built-in panel is already disabled and the TV must
# stay on. When undocked the built-in panel is the sole display, so turning its
# backlight off is the normal "screen off on idle" behavior -- and it keeps the
# panel from sitting lit on a static image while charging.
#
# We drive the backlight directly (amdgpu_bl0) rather than powerdevil, because
# powerdevil's idle screen-off is global and we must never blank the TV.
#
# Usage: steamdeck-internal-blank {off|on}

set -uo pipefail

bl=/sys/class/backlight/amdgpu_bl0
saved="${XDG_RUNTIME_DIR:-/run/user/1000}/steamdeck-internal-brightness"

# Only act inside a KWin/Plasma session; in gamescope kscreen-doctor fails and
# Steam owns brightness, so leave the panel alone there.
kscreen-doctor -j >/dev/null 2>&1 || exit 0

external_connected() {
  kscreen-doctor -j 2>/dev/null |
    jq -e 'any(.outputs[]; .connected and (.name | test("eDP") | not))' >/dev/null 2>&1
}

# Docked: never touch the backlight (panel already off, TV must stay on).
external_connected && exit 0

case "${1:-}" in
off)
  cat "$bl/brightness" >"$saved" 2>/dev/null || true
  echo 0 >"$bl/brightness" 2>/dev/null || true
  echo 4 >"$bl/bl_power" 2>/dev/null || true # FB_BLANK_POWERDOWN
  ;;
on)
  echo 0 >"$bl/bl_power" 2>/dev/null || true # FB_BLANK_UNBLANK
  if [[ -r $saved ]]; then
    cat "$saved" >"$bl/brightness" 2>/dev/null || true
  fi
  ;;
esac
