# niri sessions drop to the greeter on a stray Ctrl+C (tty-generated SIGINT)

**Labels**: bug, niri, greetd, fleet-wide
**Related**: greeter overhaul (#692), foxtrot-drop-plasma

## Symptom

On greetd + niri hosts, the niri session intermittently "crashes" back to the
ReGreet greeter — reproducibly when pressing a copy shortcut / `Ctrl+C` in a
terminal, especially (but not only) during startup before the shell/DMS is fully
up. niri itself never crashes.

## Root cause (strace-confirmed on flab, 2026-07-08)

greetd runs each session as a **root** `greetd --session-worker` on **tty1**, and
the whole `niri-session` launch chain (`fish` → `sh` → `systemctl --user --wait
start niri.service`) sits in **tty1's foreground process group** with tty1 as its
controlling terminal. niri runs on that same VT but takes input via libinput/evdev
— it does **not** disable the VT keyboard (`K_OFF`).

So a `Ctrl+C` that reaches tty1's line discipline makes the **kernel** send SIGINT
to the entire foreground process group, including the root session-worker leader.
strace on greetd caught it exactly:

```
16253  --- SIGINT {si_signo=SIGINT, si_code=SI_KERNEL} ---            (leader, uid 0)
...    (also delivered to the fish/sh niri-session chain on tty1)
1545   SIGCHLD {CLD_KILLED, si_pid=16253, si_uid=0, si_status=SIGINT} (greetd reaps it)
```

`si_code=SI_KERNEL` proves it's the controlling tty, not a process — and a
uid-1000 process (niri/DMS all run as the user) legally cannot SIGINT a root
process, so only the tty could. The leader dies → greetd falls back to the
greeter. niri is left orphaned/paused (loses DRM master), never crashing.

## Fix (this PR)

Clear the controlling tty's signal-generating chars (`stty -isig`) before
launching the compositor, for **both** greetd session leaders (both are root on
tty1):

- **Greeter** (`lib/modules/nixos/greeter.nix`): one line before
  `exec dbus-run-session niri`.
- **User session** (`lib/modules/nixos/niri.nix`): wrap `programs.niri.package`
  with a `symlinkJoin` that rewrites the `niri.desktop` `Exec` to a small shim
  which runs `stty -isig < /dev/tty` then `exec`s the upstream `niri-session`.

`-isig` stops the kernel generating SIGINT/SIGQUIT/SIGTSTP from the VT line
discipline. niri reads input via libinput (never the tty), so this is transparent;
process group, controlling tty, VT switching, `Mod+Shift+E quit`, and logout are
all unchanged. The `|| true` guard makes a missing ctty a no-op, not a login
failure.

## Upstream follow-up (not in this PR)

The "correct" upstream fix is for **niri to disable the VT keyboard (`K_OFF` /
`VT_SETMODE`)** so keystrokes never reach the tty line discipline at all. That's a
niri behavior change / version concern (26.04 here); file/track separately rather
than bundling with this defensive config fix.
