# OrcaSlicer via the upstream AppImage.
#
# The nixpkgs orca-slicer build has a broken 3D viewport on this system: its
# wxWidgets GL canvas calls glewInit() with no current GL context
# ("Unable to init glew library, Error: Missing GL version") and the viewport
# renders blank white, while the GTK sidebar renders fine. Raw GLX works (proven
# with glxgears under the same XWayland path), so this is an orca-slicer/wxWidgets
# build bug, not a driver/compositor issue. The official AppImage bundles its own
# wx/GLEW and renders correctly. See issues/open/orca-slicer-nixpkgs-blank-viewport.md.
#
# This shadows nixpkgs' orca-slicer via lib/overlays (packages/ are merged onto
# pkgs), so `pkgs.orca-slicer` resolves to this working build everywhere. Revisit
# and drop this once nixpkgs#orca-slicer renders again.
#
# To update: bump `version`, then refresh `hash` from the fetchurl error (or
# `nix hash file` on the downloaded AppImage).
{
  appimageTools,
  fetchurl,
  makeWrapper,
  symlinkJoin,
}:
let
  pname = "orca-slicer";
  version = "2.4.2";

  src = fetchurl {
    url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v${version}/OrcaSlicer_Linux_AppImage_Ubuntu2404_V${version}.AppImage";
    hash = "sha256-0S+4yOrBrs0t+2N3rNSPmU+PpDntUpL6Uy3YKIDwKf0=";
  };

  # The stock appimage FHS env lacks WebKitGTK 4.1; the AppImage refuses to start
  # without libwebkit2gtk-4.1.so.0 / libjavascriptcoregtk-4.1.so.0.
  wrapped = appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = pkgs: [
      pkgs.webkitgtk_4_1
      pkgs.libsoup_3
    ];
  };
in
# Force XWayland: native Wayland crashes wxWidgets on this build
# (GLib-GObject-CRITICAL in GTK widget setup before the window maps).
symlinkJoin {
  name = "${pname}-${version}";
  paths = [ wrapped ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/${pname} --set GDK_BACKEND x11
  '';

  meta = wrapped.meta // {
    description = "G-code generator for 3D printers (Bambu, Prusa, Voron, …) — upstream AppImage, working 3D viewport";
    mainProgram = pname;
  };
}
