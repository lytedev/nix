# foxtrot: exit gaming mode from the controller

`foxtrot-gamemode` runs Steam inside a nested **gamescope** (so the controller,
Steam overlay, and controller-as-mouse all work). The catch: gamescope makes
Steam show the SteamOS **"Deck" power menu**, whose **"Switch to Desktop"** is a
SteamOS-only session action that the **Flatpak** Steam never implements — it
makes no D-Bus call and just hangs on "Switching to Desktop…" forever (verified
live with `dbus-monitor` on both buses). It cannot be shimmed: Steam never emits
the call. (An earlier `com.steampowered.SteamOSManager1` shim was tried and
removed for exactly this reason.)

## How exit works instead

A **non-Steam shortcut** drops a sentinel file that a systemd `.path` unit
watches (event-driven — systemd's own inotify, no polling and no idle process):

- `foxtrot-gamemode-exit.path` watches
  `~daniel/.var/app/com.valvesoftware.Steam/.local/share/Steam/.foxtrot-exit-gamemode`
  and triggers `foxtrot-gamemode-exit.service`, which terminates the gaming-mode
  gamescope (matched by argv[0] + Steam gamepadui markers) and removes the
  sentinel (re-arming the `.path`). The foreground `gamescope` in the launcher
  then returns and its trap restores idle/lock.
- Steam's data dir is bind-shared into the Flatpak sandbox at the **same absolute
  path**, so a `touch` from inside the sandbox is seen on the host. No SteamOS
  session manager and no `flatpak-spawn` portal are involved (the portal is
  blocked on this Flatpak anyway).

Once on niri, the controllers' own mouse mode drives the desktop.

## One-time setup: add the "Exit Gaming Mode" library entry

Do this once from **desktop** Steam (regular UI, easiest with keyboard/mouse);
afterwards it's launchable from the controller in gaming mode forever.

1. Steam → **Games → Add a Non-Steam Game to My Library → Browse**.
2. Pick `/usr/bin/touch` (toggle "All Files" if needed).
3. Right-click the new entry → **Properties**:
   - **Name:** `Exit Gaming Mode`
   - **Launch Options:**
     `/home/daniel/.var/app/com.valvesoftware.Steam/.local/share/Steam/.foxtrot-exit-gamemode`
   - (optional) set an icon.

In gaming mode, navigate to **Exit Gaming Mode** in the library and launch it →
gamescope quits and you're back on niri.

## Idle note

The launcher disables all idle paths for the session and restores them on exit:
stops **swayidle** (the real idle daemon — it runs lock/suspend/dpms and does not
honor `systemd-inhibit`), and zeroes **both** DMS timers — `acLockTimeout` (screen
lock) *and* `acMonitorTimeout` (DPMS display-off; `IdleService.qml`:
`monitorOffMonitor.enabled = monitorTimeout > 0`, so `0` = disabled). Without
disabling the monitor timer too, the display would still DPMS-off mid-game once
niri sees no input (controller input goes to gamescope, not niri).
