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
#   2. Undocked -> the built-in panel is the only display; leave it on and let
#      powerdevil turn it off on idle -- including while charging (on AC), not
#      just on battery.
#   3. The TV must never be force-blanked on idle.
#
# powerdevil's "turn off display when idle" is global (it can't target a single
# output) and its inhibitor handling is unreliable, so we do NOT try to make it
# idle-off only the internal panel. Instead:
#   - powerdevil owns idle screen-off for the undocked panel (goal 2).
#   - While an external output is connected we disable the internal panel
#     (goal 1) and hold a ScreenSaver inhibit so powerdevil's global idle
#     screen-off can't blank the TV (goal 3).
#
# Runs as a user service in the graphical (Plasma/KWin) session. In a gamescope
# gaming session kscreen-doctor is a no-op and the calls fail harmlessly.

set -uo pipefail

edp=eDP-1
inhibit_pid=""

# True when any connected output other than the built-in eDP panel is present
# (i.e. we're docked to a TV/monitor). Keyed off "non-eDP connected" rather than
# a hardcoded DP-1 so it works on any dock, port, or connector name.
external_connected() {
  kscreen-doctor -j 2>/dev/null |
    jq -e 'any(.outputs[]; .connected and (.name | test("eDP") | not))' >/dev/null 2>&1
}

hold_inhibit() {
  if [[ -z $inhibit_pid ]] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
    kde-inhibit --screenSaver sleep infinity &
    inhibit_pid=$!
  fi
}

drop_inhibit() {
  if [[ -n $inhibit_pid ]]; then
    kill "$inhibit_pid" 2>/dev/null || true
    wait "$inhibit_pid" 2>/dev/null || true
    inhibit_pid=""
  fi
}

apply() {
  if external_connected; then
    kscreen-doctor output."$edp".disable >/dev/null 2>&1 || true
    hold_inhibit
  else
    kscreen-doctor output."$edp".enable >/dev/null 2>&1 || true
    drop_inhibit
  fi
}

trap drop_inhibit EXIT

# Wait for the Wayland session to be reachable before touching anything; the
# service can start before Plasma has exported WAYLAND_DISPLAY into the user
# systemd environment.
for _ in $(seq 1 30); do
  kscreen-doctor -j >/dev/null 2>&1 && break
  sleep 2
done

# Turn the built-in display off on idle even while charging. Battery already
# does this (10 min); AC shipped with it disabled, which is what let the docked
# panel stay lit indefinitely. Takes effect on the next login if a live reload
# isn't available.
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle true
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutSec 600

apply

# Re-apply on every display hotplug (dock / undock).
while read -r _; do
  sleep 1
  apply
done < <(udevadm monitor --udev --subsystem-match=drm 2>/dev/null)
