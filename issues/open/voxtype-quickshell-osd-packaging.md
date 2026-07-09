# voxtype: package the Quickshell OSD QML tree (currently user-installed)

**Labels**: desktop, voxtype, packaging
**Related**: PR #736 (voxtype OSD/GPU fixes), PR #734 (niri Super+V bind)

The voxtype OSD frontend that actually renders daemon **states**
(recording / streaming / transcribing icon + tint + waveform) is the
Quickshell one. The gtk4 frontend that PR #736 puts on the service PATH only
draws a waveform while audio frames flow — no processing/typing feedback —
so dragon's user config selects `[osd] frontend = "quickshell"`.

The catch: the voxtype nix package ships the `voxtype-osd-quickshell`
launcher binary but **not the QML tree it needs** (`shell.qml` etc. — nothing
under `$out/share/voxtype/quickshell/`). Upstream's flake doesn't install it
(checked at rev `31b7f38c`). On dragon this was worked around live with:

```
voxtype setup quickshell --source <voxtype src checkout>/quickshell
# → installs to ~/.local/share/voxtype/quickshell/
```

plus `/run/current-system/sw/bin` appended to the voxtype service PATH so the
launcher can find `qs` (quickshell). Both are user-mutable state that a fresh
machine/user would silently lack — the OSD would fall back to gtk4 (or die if
gtk4 also missing).

## What to do

- In the overlay's voxtype rewrap, copy `${src}/quickshell/` into
  `$out/share/voxtype/quickshell/` (the launcher's search path includes
  `<binary>/../share/voxtype/quickshell/`), or wrap `voxtype-osd-quickshell`
  with `VOXTYPE_OSD_QML_PATH` pointing at a store path of the QML tree.
- Put `quickshell` on the voxtype service path in desktop.nix (today only
  the live drop-in on dragon has it).
- Consider upstreaming: the flake could install the QML tree next to the
  launcher it already ships.

Also user-level (not nix-managed, noted for context): dragon's
`~/.config/voxtype/config.toml` sets `frontend = "quickshell"` and
`[vad] enabled = true` (Silero, discards silence-only recordings instead of
hallucinating "Thank you."), and `voxtype setup dms --install` added a DMS
bar widget at `~/.config/DankMaterialShell/plugins/VoxtypeWidget/`.

## Upstream bugs in `voxtype setup dms` (0.7.5) — report to voxtype

The generated DMS widget was broken two ways and was fixed by hand on dragon
(`VoxtypeStatus.qml`, rewritten 2026-07-09):

1. **No `plugin.json` manifest.** DMS 1.5's plugin system only discovers
   plugins with a manifest (`id`, `name`, `components.widget`); the generator
   writes only the QML, so DMS reports "No plugins found".
2. **Wrong Process API + hardcoded store path.** The QML calls
   `Process.start(...)` / `readAllStandardOutput()` (QProcess semantics) which
   Quickshell's `Process` type doesn't have — "Process is not a type" without
   `import Quickshell.Io`, method errors with it. It also bakes in the
   absolute `/nix/store/.../bin/voxtype` path, stale after any rebuild.

The hand fix watches `$XDG_RUNTIME_DIR/voxtype/state` with a
`Quickshell.Io.FileView` (event-driven; the same pattern as voxtype's own
`voxtype-shared/StateReader.qml`) and click-toggles via
`Quickshell.execDetached(["voxtype", "record", "toggle"])` from PATH.

Debugging note: after editing a broken plugin's QML, DMS's `plugin-scan
rescan` does NOT clear Qt's component cache (stale "component error" with old
line numbers, then "File name case mismatch" after a rename) — restart
`dms.service` to actually reload the QML.

## Streaming dictation (Parakeet) — setup notes + more upstream bugs

dragon now runs `engine = "parakeet"` with `[parakeet] streaming = true`
(type-as-you-speak at the cursor; Super+V toggles the session). This needed
the flake's **`onnx` package** (`parakeet-load-dynamic` feature) — the
whisper-vulkan build has no parakeet support. The daemon drop-in on dragon
currently points at a scratch `voxtype-onnx-wrapped` store path; for the
declarative fix the overlay needs an ONNX rewrap variant (and a decision:
ship onnx-only, or a custom combined `gpu-vulkan`+onnx feature build so
whisper keeps GPU accel when selected).

Upstream bugs hit on the way (voxtype 0.7.5, report with the DMS ones):

1. **Streaming needs `parakeet-unified-en-0.6b`, but `voxtype setup
   --download --model` doesn't offer it** (only the tdt-v3 batch models).
   Had to read `src/setup/model.rs` for the manifest and curl the 5 files
   from `huggingface.co/bobNight/parakeet-unified-en-0.6b-onnx` (~2.4 GB)
   into `~/.local/share/voxtype/models/parakeet-unified-en-0.6b/`.
2. **voxtype's streaming timing defaults crash the daemon.** Its defaults
   (left 1.5s / chunk 0.5s / right 0.5s) fail parakeet-rs validation —
   each value must map to a mel-frame count divisible by 8, i.e. be a
   multiple of 0.08s (frames = secs × 16000/160). Fixed in config with
   parakeet-rs 0.3.5's own Default values: left 5.6 / chunk 0.56 /
   right 0.56.
