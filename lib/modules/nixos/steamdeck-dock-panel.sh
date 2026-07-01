#!/usr/bin/env bash
#
# Home-theater dock display controller for the Steam Deck.
#
# This deck normally lives docked to the living-room TV (an external DP/HDMI
# output) but is also used handheld. Goals:
#
#   1. Docked  -> drive ONLY the TV. The built-in panel must be OFF -- both its
#      output disabled AND its backlight powered down. (Disabling the eDP output
#      does NOT cut the backlight: it's a separate device, so the LCD keeps
#      glowing at its last brightness, which is what caused the temporary image
#      retention.)
#   2. The TV must never be force-blanked on idle.
#   3. Undocked -> the built-in panel is on; it turns off on idle (on AC as well
#      as battery) via steamdeck-internal-idle, which blanks only this backlight.
#
# powerdevil's idle screen-off is global and a ScreenSaver inhibit doesn't
# reliably stop its DPMS, so powerdevil is taken out of display-blanking
# (TurnOffDisplayWhenIdle=false, both profiles) and we manage the panel here.
#
# Runs as a user service in the graphical (Plasma/KWin) session. In a gamescope
# gaming session kscreen-doctor is a no-op and the calls fail harmlessly.

set -uo pipefail

edp=eDP-1
bl=/sys/class/backlight/amdgpu_bl0
saved="${XDG_RUNTIME_DIR:-/run/user/1000}/steamdeck-internal-brightness"
default_brightness=32768

# True when any connected output other than the built-in eDP panel is present
# (i.e. we're docked). Keyed off "non-eDP connected" rather than a hardcoded
# DP-1 so it works on any dock, port, or connector name.
external_connected() {
  kscreen-doctor -j 2>/dev/null |
    jq -e 'any(.outputs[]; .connected and (.name | test("eDP") | not))' >/dev/null 2>&1
}

# Power the built-in backlight down, remembering the current level first (but
# never overwriting a good saved level with 0, so a dock-while-idle can't lose
# the real brightness). bl_power=4 (FB_BLANK_POWERDOWN) is the true off; it needs
# the udev rule (applies on reboot), while brightness=0 works immediately.
backlight_off() {
  local cur
  cur=$(cat "$bl/brightness" 2>/dev/null || echo 0)
  if [[ ${cur:-0} -gt 0 ]]; then printf '%s' "$cur" >"$saved" 2>/dev/null || true; fi
  echo 0 >"$bl/brightness" 2>/dev/null || true
  echo 4 >"$bl/bl_power" 2>/dev/null || true
}

backlight_on() {
  echo 0 >"$bl/bl_power" 2>/dev/null || true
  local target=$default_brightness
  [[ -r $saved ]] && target=$(cat "$saved" 2>/dev/null || echo "$default_brightness")
  echo "$target" >"$bl/brightness" 2>/dev/null || true
}

# Track dock state so we only restore the panel on a real undock transition and
# don't fight steamdeck-internal-idle's blanking on a spurious undocked event.
prev=""
apply() {
  if external_connected; then
    # Re-assert every time so a re-lit backlight while docked gets corrected.
    kscreen-doctor output."$edp".disable >/dev/null 2>&1 || true
    backlight_off
    prev=docked
  else
    if [[ $prev == docked ]]; then
      kscreen-doctor output."$edp".enable >/dev/null 2>&1 || true
      backlight_on
    fi
    prev=undocked
  fi
}

# Wait for the Wayland session to be reachable; the service can start before
# Plasma has exported WAYLAND_DISPLAY into the user systemd environment.
for _ in $(seq 1 30); do
  kscreen-doctor -j >/dev/null 2>&1 && break
  sleep 2
done

# Take powerdevil out of display idle-off entirely so it can never blank the TV.
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kwriteconfig6 --file powerdevilrc --group Battery --group Display --key TurnOffDisplayWhenIdle false

apply

# Re-apply on every display hotplug (dock / undock).
while read -r _; do
  sleep 1
  apply
done < <(udevadm monitor --udev --subsystem-match=drm 2>/dev/null)
