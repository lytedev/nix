# Steam crashes when launching Prism Launcher (extest NoCompositor panic)

**Labels**: steam, steamdeck, gaming
**Related**: `lib/modules/nixos/gaming.nix`

## Symptom

On the steamdeck host, launching the Prism Launcher (the `org.prismlauncher.PrismLauncher`
Flatpak, added to Steam as a non-Steam shortcut) crashes the whole Steam client.
Repeated SIGABRT coredumps from `~/.local/share/Steam/ubuntu12_32/steam`.

## Root cause

Not a Prism or Steam bug. It's the **`extest`** shim, enabled via
`programs.steam.extest.enable = true`. extest is a Rust `LD_PRELOAD` library that
translates Steam Input's XTest calls into Wayland input events.

Crash chain (from `journalctl -b -1`):

```
thread '<unnamed>' panicked at src/wayland.rs:27:45:
called `Result::unwrap()` on an `Err` value: NoCompositor
panic in a function that cannot unwind
13: XTestFakeRelativeMotionEvent      <- C FFI boundary (nounwind)
18: SteamThreadTools::CThread::ThreadProc
thread caused non-unwinding panic. aborting.   -> SIGABRT
```

1. Prism launches fine as a non-Steam shortcut.
2. Steam Input activates that shortcut's (desktop-style) controller layout and
   injects emulated mouse motion via `XTestFakeRelativeMotionEvent`.
3. The call hits extest instead of libXtst; extest's wayland backend `.unwrap()`s
   a compositor connection, gets `NoCompositor`, and panics.
4. The panic crosses the `extern "C"` / nounwind FFI boundary -> `abort()` -> the
   entire Steam process dies.

Any non-Steam XWayland app with a mouse/keyboard-emulating controller layout
would trigger the same crash; Prism was just the trigger.

## Fix

Disabled `programs.steam.extest.enable` in `lib/modules/nixos/gaming.nix`.
gamescope handles controller input natively in Game Mode, so the XTest->Wayland
shim isn't needed. This applies to every host with `programs.steam.enable`.

Alternative (not taken): set the Prism shortcut's Steam Input layout to "Gamepad"
or disable Steam Input for it, leaving extest enabled for other apps.
