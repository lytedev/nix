# foxtrot suspend behaviour.
#
# History: this began as a "wake foxtrot when the VITURE glasses are plugged in"
# module — it armed USB wakeup on the XHC4 USB-C controller and ran a resume gate
# to re-suspend spurious wakes. That wake-on-USB-plug was dropped (2026-06-25):
# arming USB controllers for wakeup is a trigger for an AMD s2idle *resume hang*
# on this Framework 13 — the machine would enter s2idle on lid-close and never
# come back (no resume logged; not even the power button recovers a wedged
# s2idle — hard reset only).
#
# What this module does now:
#   1. disarm-usb-wakeup: a oneshot run *before every sleep* that disables wakeup
#      on all USB controllers + devices. They are armed by the kernel default and
#      the xHCI driver re-arms them on every resume with NO udev event to hook
#      (verified: XHC0/1/3 have no udev rule yet come up armed; a `udevadm trigger
#      --action=add` does not re-arm a disabled controller), so a one-shot or
#      udev-rule disable can't hold. Re-running before each suspend guarantees
#      wakeup is off at the moment we enter s2idle, which is what the hang depends
#      on; the harmless re-arm on resume is cleaned up before the next sleep.
#      Trade-off: no wake-on-USB-plug. The lid switch and power button still wake.
#   2. viture-keepawake: holds a `sleep` inhibitor while an external display is
#      connected AND we're on AC, so a docked session (glasses or any monitor)
#      survives both the lid handler and swayidle's idle `systemctl suspend`. It
#      blocks *suspend* only — swayidle's idle *lock* still fires, so stepping
#      away still locks.
#
# Watch both with:  journalctl -t s2idle-wakeup-fix -t viture-wake -f
{ pkgs, lib, ... }:
let
  binPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.systemd
    pkgs.util-linux
  ];

  disarmUsbWakeup = pkgs.writeShellScript "disarm-usb-wakeup" ''
    export PATH=${binPath}
    log() { logger -t s2idle-wakeup-fix -- "$*"; }
    n=0
    # xHCI USB controllers (PCI class 0x0c0330) arm the PME that wakes the system
    # from s2idle — arming them is what wedges resume on this board.
    for d in /sys/bus/pci/devices/*; do
      [ -r "$d/class" ] || continue
      [ "$(cat "$d/class" 2>/dev/null)" = "0x0c0330" ] || continue
      w="$d/power/wakeup"
      if [ -w "$w" ] && [ "$(cat "$w" 2>/dev/null)" = "enabled" ]; then
        echo disabled > "$w" 2>/dev/null && n=$((n + 1))
      fi
    done
    # USB devices (root hubs + peripherals: glasses, controller puck, etc.).
    for w in /sys/bus/usb/devices/*/power/wakeup; do
      if [ -w "$w" ] && [ "$(cat "$w" 2>/dev/null)" = "enabled" ]; then
        echo disabled > "$w" 2>/dev/null && n=$((n + 1))
      fi
    done
    log "disarmed USB wakeup on $n controller(s)/device(s) before sleep"
  '';

  keepAwake = pkgs.writeShellScript "viture-keepawake" ''
    export PATH=${binPath}
    log() { logger -t viture-wake -- "$*"; }

    # Any external (non-eDP) display connected — the glasses' DP-alt-mode output
    # or a regular monitor.
    external_display_present() {
      local s
      for s in /sys/class/drm/card*-*/status; do
        case "$s" in
          *eDP*) continue ;;
        esac
        [ "$(cat "$s" 2>/dev/null)" = "connected" ] && return 0
      done
      return 1
    }

    # On AC when the battery is not discharging (Charging / Not charging / Full)
    # or any USB-C PD source is online. ACAD/online is deliberately NOT used — it
    # reads 1 even on battery on this board.
    on_ac() {
      local s u
      s=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null)
      if [ -n "$s" ] && [ "$s" != "Discharging" ] && [ "$s" != "Unknown" ]; then
        return 0
      fi
      for u in /sys/class/power_supply/ucsi-source-psy-*/online; do
        [ -r "$u" ] && [ "$(cat "$u" 2>/dev/null)" = "1" ] && return 0
      done
      return 1
    }

    inhibit_pid=""
    cleanup() { [ -n "$inhibit_pid" ] && kill "$inhibit_pid" 2>/dev/null || true; }
    trap cleanup EXIT INT TERM

    # Hold the inhibitor while an external display is connected AND we're on AC.
    # A short debounce avoids dropping it on a transient battery-status flap.
    held=0
    miss=0
    log "keepawake watcher started (holds sleep inhibitor while external display + AC present)"
    while :; do
      keep=0
      if external_display_present && on_ac; then keep=1; fi
      if [ "$keep" = 1 ]; then
        miss=0
        if [ "$held" = 0 ] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
          log "external display + AC present -> holding sleep inhibitor (lid close / idle won't suspend; idle still locks)"
          systemd-inhibit --what=sleep:handle-lid-switch --who="viture-glasses" \
            --why="external display connected on AC; keep awake (lid closed ok)" \
            --mode=block sleep infinity &
          inhibit_pid=$!
          held=1
        fi
      else
        if [ "$held" = 1 ]; then
          # debounce: only release after 3 consecutive misses (~9s)
          miss=$((miss + 1))
          if [ "$miss" -ge 3 ]; then
            log "external display/AC gone -> releasing sleep inhibitor (extdisp=$(external_display_present && echo yes || echo no) ac=$(on_ac && echo yes || echo no))"
            kill "$inhibit_pid" 2>/dev/null || true
            inhibit_pid=""
            held=0
            miss=0
          fi
        fi
      fi
      sleep 3
    done
  '';
in
{
  # Disarm USB wakeup before every sleep — works around the AMD s2idle resume
  # hang. xHCI controllers re-arm wakeup on resume (kernel default, no udev
  # event), so this oneshot re-runs before each suspend, ordered Before the sleep
  # services so it completes while still awake.
  systemd.services.disarm-usb-wakeup = {
    description = "Disarm USB wakeup before sleep (AMD s2idle resume-hang workaround)";
    before = [
      "systemd-suspend.service"
      "systemd-suspend-then-hibernate.service"
      "systemd-hibernate.service"
      "systemd-hybrid-sleep.service"
    ];
    wantedBy = [
      "suspend.target"
      "suspend-then-hibernate.target"
      "hibernate.target"
      "hybrid-sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = disarmUsbWakeup;
    };
  };

  # Keep a docked session (glasses or any external monitor) alive with the lid
  # closed while on AC. Blocks suspend only; idle lock still fires.
  systemd.services.viture-keepawake = {
    description = "VITURE/dock: keep awake (suspend inhibitor) while external display + AC connected";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = keepAwake;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
