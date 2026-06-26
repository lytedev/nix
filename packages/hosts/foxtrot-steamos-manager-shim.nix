# foxtrot: make Steam's gamepad-UI "Switch to Desktop" actually work.
#
# Problem: in "gaming mode" (Steam runs inside a nested gamescope — see
# foxtrot-gamemode in foxtrot.nix), Steam detects gamescope by PID and renders
# the SteamOS/"Deck" power menu. Its "Switch to Desktop" item is NOT a shell
# command — it's a D-Bus call to the name `com.steampowered.SteamOSManager1`
# (interface SessionManagement1, method SwitchToDesktop / SwitchToDesktopMode),
# which on SteamOS is served by Valve's `steamos-manager` daemon (rewrites the
# display-manager autologin and bounces graphical-session.target).
#
# On foxtrot that name does not exist on the session bus, and the Steam Flatpak
# manifest doesn't even grant `--talk-name=com.steampowered.SteamOSManager1`, so
# the call dies in the sandbox's D-Bus proxy and the UI hangs forever on
# "Switching to Desktop…".
#
# Refs (SHA-pinned):
#   steamos-manager SwitchToDesktopMode handler:
#     https://github.com/bazzite-org/steamos-manager/blob/e9665737341d7aaa1764cfbdab368ce47a7e3d15/steamos-manager/src/manager/user.rs#L1168
#   Flatpak manifest (no SteamOSManager1 talk-name, no host-spawn):
#     https://github.com/flathub/com.valvesoftware.Steam/blob/9feda86829a1329e385f8040e3c5e10d152aff10/com.valvesoftware.Steam.yml#L20-L46
#
# foxtrot's "desktop" already exists *underneath* gamescope (niri is the real
# session; gamescope only hosts Steam). So we don't need SteamOS's whole
# display-manager bounce — we just provide the D-Bus name Steam is calling and
# have its handler terminate gamescope, which collapses the nested session back
# to niri. The handler is a deliberate catch-all: it logs the exact method/path/
# signature Steam sends and acts on any *Desktop / *SwitchTo* method, so it works
# whether this client calls the old `SwitchToDesktop` or the newer
# `SwitchToDesktopMode`, and always replies success so the UI never hangs.
#
# The Flatpak proxy must also be allowed to reach the name; that override is
# applied out-of-band (see lib/doc / the deploy notes) — without
# `flatpak override --user --talk-name=com.steampowered.SteamOSManager1
# com.valvesoftware.Steam` the call never leaves the sandbox.
#
# Power actions (Suspend/Restart/Shut Down) do NOT go through SteamOSManager1 —
# they use logind/session-manager interfaces and are a separate concern.
{ pkgs, lib, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);

  shimScript = pkgs.writeText "steamos-manager-shim.py" ''
    import asyncio
    import os
    import signal
    import sys

    from dbus_next.aio import MessageBus
    from dbus_next.constants import BusType, MessageType
    from dbus_next import Message

    NAME = "com.steampowered.SteamOSManager1"

    # Target ONLY the gaming-mode gamescope. Match a process whose argv[0]
    # basename is *exactly* "gamescope" (the compositor) AND whose argv carries
    # both markers below — i.e. the `flatpak run com.valvesoftware.Steam
    # -gamepadui` that foxtrot-gamemode launches. This excludes the
    # "gamescopereaper" helper (argv[0]="gamescopereaper") and the nested
    # pressure-vessel/steam-runtime helpers, and never matches a separate,
    # unrelated `gamescope <somegame>`. Signature-based, so there's no pidfile to
    # go stale and no coupling to the launcher.
    #
    # NB: we key on argv[0], NOT comm — the live compositor's comm is
    # "gamescope-wl" (it's the setcap-wrapped .gamescope-wrapped), so a
    # comm == "gamescope" match would find nothing.
    GAMESCOPE_ARGV0 = b"gamescope"
    GAMING_MODE_MARKERS = (b"com.valvesoftware.Steam", b"-gamepadui")

    INTROSPECT_XML = (
        '<!DOCTYPE node PUBLIC '
        '"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" '
        '"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">'
        '<node>'
        '<interface name="org.freedesktop.DBus.Introspectable">'
        '<method name="Introspect"><arg name="xml" type="s" direction="out"/></method>'
        '</interface>'
        '<interface name="com.steampowered.SteamOSManager1.SessionManagement1">'
        '<method name="SwitchToDesktop"/>'
        '<method name="SwitchToDesktopMode"/>'
        '</interface>'
        '</node>'
    )

    def log(msg):
        print("steamos-manager-shim: " + msg, file=sys.stderr, flush=True)

    def find_gaming_mode_gamescopes():
        pids = []
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            pid = int(entry)
            try:
                with open("/proc/{}/cmdline".format(pid), "rb") as f:
                    cmdline = f.read()
            except OSError:
                continue
            if not cmdline:
                continue
            argv0 = os.path.basename(cmdline.split(b"\x00", 1)[0])
            if argv0 != GAMESCOPE_ARGV0:
                continue
            if all(marker in cmdline for marker in GAMING_MODE_MARKERS):
                pids.append(pid)
        return pids

    def switch_to_desktop():
        # gamescope is the parent of the nested Steam; terminating it collapses
        # gaming mode back to the underlying niri session ("the desktop").
        pids = find_gaming_mode_gamescopes()
        if not pids:
            log("switch-to-desktop requested but no gaming-mode gamescope found; nothing to kill")
            return
        log("switch-to-desktop requested -> terminating gaming-mode gamescope pid(s): {}".format(pids))
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError as e:
                log("  kill {} failed: {}".format(pid, e))

    async def main():
        bus = await MessageBus(bus_type=BusType.SESSION).connect()

        def handler(msg):
            if msg.message_type != MessageType.METHOD_CALL:
                return None
            log(
                "CALL path={} iface={} member={} sig={} args={}".format(
                    msg.path, msg.interface, msg.member, msg.signature, msg.body
                )
            )
            if (
                msg.interface == "org.freedesktop.DBus.Introspectable"
                and msg.member == "Introspect"
            ):
                return Message.new_method_return(msg, "s", [INTROSPECT_XML])
            member = msg.member or ""
            if ("Desktop" in member) or ("SwitchTo" in member):
                switch_to_desktop()
            # Always reply success so Steam's UI never hangs on "Switching to…".
            return Message.new_method_return(msg)

        bus.add_message_handler(handler)
        reply = await bus.request_name(NAME)
        log("requested {}: {}".format(NAME, reply))
        await bus.wait_for_disconnect()

    asyncio.run(main())
  '';

  shimBin = pkgs.writeShellScriptBin "steamos-manager-shim" ''
    exec ${pythonEnv}/bin/python3 ${shimScript}
  '';
in
{
  # Always-on user service owning com.steampowered.SteamOSManager1 on the user
  # session bus (the same bus the Steam Flatpak proxy connects to). Debuggable
  # via `journalctl --user -u steamos-manager-shim -f`.
  systemd.user.services.steamos-manager-shim = {
    description = "Shim for Steam gamepad-UI Switch-to-Desktop (kills gamescope -> niri)";
    wantedBy = [
      "graphical-session.target"
      "default.target"
    ];
    serviceConfig = {
      ExecStart = lib.getExe shimBin;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
