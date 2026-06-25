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
#   3. viture-keepawake holds a `handle-lid-switch` block inhibitor while the
#      glasses are connected, so closing the lid mid-session doesn't suspend.
#      (logind here is configured to suspend-then-hibernate on lid close in all
#      cases, so the inhibitor is required — dock detection won't help.)
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
    systemctl suspend
  '';

  keepAwake = pkgs.writeShellScript "viture-keepawake" ''
    ${helpers}
    inhibit_pid=""
    cleanup() { [ -n "$inhibit_pid" ] && kill "$inhibit_pid" 2>/dev/null || true; }
    trap cleanup EXIT INT TERM

    log "keepawake watcher started (holds lid inhibitor while glasses connected)"
    while :; do
      if glasses_present; then
        if [ -z "$inhibit_pid" ] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
          log "glasses connected -> holding handle-lid-switch inhibitor (lid close won't suspend)"
          systemd-inhibit --what=handle-lid-switch --who="viture-glasses" \
            --why="VITURE glasses connected; keep awake with lid closed" \
            --mode=block sleep infinity &
          inhibit_pid=$!
        fi
      else
        if [ -n "$inhibit_pid" ] && kill -0 "$inhibit_pid" 2>/dev/null; then
          log "glasses disconnected -> releasing lid inhibitor"
          kill "$inhibit_pid" 2>/dev/null || true
          inhibit_pid=""
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
