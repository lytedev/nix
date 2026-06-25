# VITURE Pro XR glasses (USB 35ca:101d) — wake foxtrot from sleep when the
# glasses are plugged in, gated on being on AC power, and keep the machine
# running with the lid closed while the glasses are connected.
#
# Everything is logged under the `viture-wake` journal tag, so you can watch /
# tune it with:  journalctl -t viture-wake -f
#
# Mechanism:
#   1. udev arms USB wakeup on the XHC4 controller (PCI 0000:c3:00.4) — the
#      USB-C port the glasses enumerate on — so plugging them in raises a wake
#      from s2idle. Scoped to *only* this controller, so the always-present
#      devices on XHC0/XHC1 (HDMI expansion card, fingerprint reader,
#      Bluetooth) are left untouched and can't cause extra wakes.
#   2. viture-wake-gate runs on every resume. If the lid is open it's a normal
#      user wake → stay awake. If the lid is closed, it stays awake only when
#      the glasses are present AND the laptop is on AC; otherwise it goes back
#      to sleep (so a spurious wake, or a plug-in while on battery, re-suspends).
#   3. viture-keepawake holds a `sleep` block inhibitor while an external
#      display is connected AND we're on AC, so a docked session (glasses or any
#      monitor) survives both the lid handler and swayidle's idle `systemctl
#      suspend` (timeout 660). It blocks *suspend* only — swayidle's idle *lock*
#      still fires, so stepping away locks. logind here is suspend-then-hibernate
#      on lid close in all cases and the compositor is niri+swayidle, so an
#      inhibitor is required (dock detection won't help). The wake-gate uses
#      `systemctl suspend -i` so it can still force-resuspend a battery/spurious
#      wake past this inhibitor.
#
# Known limitation: lid-close is suspend-then-hibernate, so wake-on-plug only
# works while the machine is still in s2idle. Once it hibernates (after the
# HibernateDelaySec), a USB plug-in can't wake it — that needs the power button.
{ pkgs, lib, ... }:
let
  vendor = "35ca";
  product = "101d";
  # XHC4 — the USB-C xHCI controller the glasses enumerate on. Matched by its
  # stable PCI address so it doesn't depend on the (volatile) usb bus number.
  controller = "0000:c3:00.4";

  binPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.systemd
    pkgs.util-linux
  ];

  # Shared shell helpers prepended to each script.
  helpers = ''
    export PATH=${binPath}
    log() { logger -t viture-wake -- "$*"; }

    glasses_present() {
      local d
      for d in /sys/bus/usb/devices/*; do
        [ -r "$d/idVendor" ] || continue
        if [ "$(cat "$d/idVendor" 2>/dev/null)" = "${vendor}" ] \
          && [ "$(cat "$d/idProduct" 2>/dev/null)" = "${product}" ]; then
          return 0
        fi
      done
      return 1
    }

    # Any external (non-eDP) display connected — the glasses' DP-alt-mode output
    # or a regular monitor. Used to keep a docked session awake regardless of
    # which external display it is.
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
    # or any USB-C PD source is online. ACAD/online is deliberately NOT used —
    # it reads 1 even on battery on this board.
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

    lid_state() {
      local key st
      read -r key st < /proc/acpi/button/lid/LID0/state 2>/dev/null
      echo "$st"
    }
  '';

  wakeGate = pkgs.writeShellScript "viture-wake-gate" ''
    ${helpers}
    lid=$(lid_state)
    if [ "$lid" != "closed" ]; then
      log "resume gate: lid=$lid -> normal/user wake, staying awake"
      exit 0
    fi

    # Lid closed: give USB enumeration + USB-C PD negotiation a few seconds to
    # settle, then require glasses AND AC, else go back to sleep.
    g=no
    a=no
    for i in $(seq 1 6); do
      g=no; a=no
      glasses_present && g=yes
      on_ac && a=yes
      if [ "$g" = yes ] && [ "$a" = yes ]; then
        log "resume gate: lid=closed glasses=yes ac=yes (after ''${i}s) -> staying awake (glasses session)"
        exit 0
      fi
      sleep 1
    done

    log "resume gate: lid=closed glasses=$g ac=$a batt=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null) -> conditions not met, re-suspending"
    # -i so we win over the keepawake sleep inhibitor (which may already be held
    # if the glasses are present but we're on battery).
    systemctl suspend -i
  '';

  keepAwake = pkgs.writeShellScript "viture-keepawake" ''
    ${helpers}
    inhibit_pid=""
    cleanup() { [ -n "$inhibit_pid" ] && kill "$inhibit_pid" 2>/dev/null || true; }
    trap cleanup EXIT INT TERM

    # Hold the inhibitor while an external display is connected AND we're on AC.
    # This keeps a docked session (glasses or any monitor) alive against BOTH
    # the lid handler and swayidle's idle `systemctl suspend` (a `sleep` block
    # inhibitor covers both; `handle-lid-switch` also stops logind reacting to
    # the lid at all). It deliberately blocks *suspend* only — swayidle's idle
    # *lock* is not a sleep op, so stepping away still locks. A short debounce
    # avoids dropping it on a transient battery-status flap (e.g. at 100%).
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
  # 1. Arm USB wakeup on the XHC4 controller so a glasses plug-in wakes foxtrot
  #    from s2idle. Scoped to this controller only.
  services.udev.extraRules = ''
    # VITURE glasses wake-on-plug: arm wakeup on XHC4 (PCI ${controller}) and its root hubs.
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="${controller}", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="xhci_hcd", KERNELS=="${controller}", ATTR{power/wakeup}="enabled"
  '';

  # 2. On every resume, re-suspend unless this was a normal (lid-open) wake or
  #    the glasses + AC are present (lid closed).
  systemd.services.viture-wake-gate = {
    description = "VITURE glasses: re-suspend on resume unless glasses + AC (lid closed)";
    wantedBy = [
      "suspend.target"
      "suspend-then-hibernate.target"
      "hybrid-sleep.target"
    ];
    after = [
      "systemd-suspend.service"
      "systemd-suspend-then-hibernate.service"
      "systemd-hybrid-sleep.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = wakeGate;
    };
  };

  # 3. While the glasses are connected, block lid-switch suspend so the laptop
  #    keeps driving them with the lid closed.
  systemd.services.viture-keepawake = {
    description = "VITURE glasses: keep awake with lid closed while connected";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = keepAwake;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
