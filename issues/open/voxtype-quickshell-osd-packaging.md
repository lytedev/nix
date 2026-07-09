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
