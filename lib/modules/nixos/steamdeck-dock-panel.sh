#!/usr/bin/env bash
#
# Home-theater dock display controller for the Steam Deck.
#
# This deck normally lives docked to the living-room TV (an external DP/HDMI
# output) but is also used handheld. Goals:
#
#   1. Docked  -> drive ONLY the TV. The built-in LCD panel must be OFF, so it
#      can't sit lit on a static Plasma desktop (which caused temporary image
#      retention on the LCD panel).
#   2. The TV must never be force-blanked on idle.
#   3. Undocked -> the built-in panel turns off on idle -- while charging (on
#      AC) as well as on battery. (Handled by steamdeck-internal-idle, which
#      blanks only the built-in panel; see that unit.)
#
# powerdevil's "turn off display when idle" is global -- it can't target a
# single output, and a ScreenSaver inhibit does NOT reliably stop its DPMS
# screen-off. So we take powerdevil out of display-blanking entirely (the TV is
# then structurally safe) and manage the built-in panel ourselves:
#   - This unit disables the built-in panel whenever an external output is
#     connected (goal 1) and re-enables it when undocked.
#   - steamdeck-internal-idle idle-offs the built-in panel's backlight (goal 3).
#
# Runs as a user service in the graphical (Plasma/KWin) session. In a gamescope
# gaming session kscreen-doctor is a no-op and the calls fail harmlessly.

set -uo pipefail

edp=eDP-1

# True when any connected output other than the built-in eDP panel is present
# (i.e. we're docked). Keyed off "non-eDP connected" rather than a hardcoded
# DP-1 so it works on any dock, port, or connector name.
external_connected() {
  kscreen-doctor -j 2>/dev/null |
    jq -e 'any(.outputs[]; .connected and (.name | test("eDP") | not))' >/dev/null 2>&1
}

apply() {
  if external_connected; then
    kscreen-doctor output."$edp".disable >/dev/null 2>&1 || true
  else
    kscreen-doctor output."$edp".enable >/dev/null 2>&1 || true
  fi
}

# Wait for the Wayland session to be reachable; the service can start before
# Plasma has exported WAYLAND_DISPLAY into the user systemd environment.
for _ in $(seq 1 30); do
  kscreen-doctor -j >/dev/null 2>&1 && break
  sleep 2
done

# Take powerdevil out of display idle-off entirely so it can never blank the TV
# (its screen-off is global and can't target one output). The built-in panel's
# idle-off is done per-output by steamdeck-internal-idle instead.
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kwriteconfig6 --file powerdevilrc --group Battery --group Display --key TurnOffDisplayWhenIdle false

apply

# Re-apply on every display hotplug (dock / undock).
while read -r _; do
  sleep 1
  apply
done < <(udevadm monitor --udev --subsystem-match=drm 2>/dev/null)
