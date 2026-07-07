# orca-slicer: nixpkgs build has a blank 3D viewport (worked around with AppImage)

**Labels**: dragon, nix, graphics, upstream
**Related**: `packages/orca-slicer.nix`, `packages/hosts/dragon.nix`

## Summary

`pkgs.orca-slicer` from nixpkgs (2.3.2) launches on dragon (niri / wlroots,
XWayland via xwayland-satellite, AMD RX 6700 XT, Mesa 26.1.3) but the **3D
viewport renders blank white**. The GTK sidebar renders fine; only the
wxWidgets GL canvas is dead.

`packages/orca-slicer.nix` works around this by shadowing `pkgs.orca-slicer`
with the upstream OrcaSlicer AppImage (2.4.2), which bundles its own
wx/GLEW and renders correctly. This issue tracks the actual upstream fix so we
can eventually drop the AppImage wrapper.

## Root cause (confirmed on dragon 2026-07-07)

OrcaSlicer's own debug log (`~/.config/OrcaSlicer/log/`) spams:

```
[error] Unable to init glew library, Error: Missing GL version
```

That is GLEW's `GLEW_ERROR_NO_GL_VERSION` — `glGetString(GL_VERSION)` returned
NULL, i.e. **there is no current GL context when the wxGLCanvas calls
`glewInit()`**. The canvas never gets a live context, so the viewport is a
blank widget.

This is **not** an environment/driver problem:

- `glxgears` renders perfectly under the same `DISPLAY=:0` xwayland-satellite
  path (captured the spinning gears) — GLX, the GPU, and Mesa are all fine.
- Every GL env lever was still ~98% blank white: `LIBGL_DRI3_DISABLE=1`,
  `GDK_GL=gles`, `LIBGL_ALWAYS_INDIRECT=1`, `MESA_GL_VERSION_OVERRIDE=3.3`,
  `GALLIUM_DRIVER=zink`.
- `GTK_USE_PORTAL=1` (the workaround from nixpkgs#539102, a *different* symptom)
  changed nothing: still 10 glewInit failures under XWayland; native Wayland
  still crashes before GL (`GLib-GObject-CRITICAL: g_signal_handlers_disconnect_matched`).

Almost certainly a wxWidgets/GLEW build-config issue in the packaged
orca-slicer (EGL-vs-GLX wxGLCanvas mismatch, or glewInit ordering) rather than
anything host-specific. The 2.4.2 AppImage on the same machine logs **zero**
glewInit failures and renders — proving it is fixable in the build.

Related but distinct: nixpkgs#539102 (orca-slicer GTK/pango/GSettings display
failure on KDE Plasma + native Wayland). Same package, different failure layer.

## TODO (upstream fix, to drop the AppImage wrapper)

- Reproduce with a local `orca-slicer.overrideAttrs` and inspect how its
  wxGLCanvas context is created vs. what GLEW expects (EGL vs GLX).
- Check whether nixpkgs' `wxGTK32` is built with the GL backend orca-slicer's
  GLEW assumes; try building orca-slicer against a GLX wxGLCanvas.
- If confirmed, file/track a nixpkgs issue + PR, then drop
  `packages/orca-slicer.nix` and this shadow.
