{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook3,
  glib,
  gtk3,
  gnome-desktop,
  gsettings-desktop-schemas,
  json-glib,
  libhandy,
  libxkbcommon,
  wayland,
  wayland-protocols,
  wayland-scanner,
  feedbackd,
  gmobile,
  systemd,
  hunspell,
  fzf,
  libxml2,
  python3,
}:
stdenv.mkDerivation rec {
  pname = "stevia";
  version = "0.52.0";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "World/Phosh";
    repo = "stevia";
    rev = "v${version}";
    hash = "sha256-LE2+1RkxD8Sj2H/3NFzcYXZktlVGoNzWrE0UO5sJCAM=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook3
    wayland-scanner
    libxml2 # for xmllint
    python3 # for build scripts
  ];

  postPatch = ''
    patchShebangs tools/
  '';

  buildInputs = [
    glib
    glib.dev # for gio-unix-2.0 headers
    gtk3
    gnome-desktop
    gsettings-desktop-schemas
    json-glib
    libhandy
    libxkbcommon
    wayland
    wayland-protocols
    feedbackd
    gmobile
    systemd
    hunspell
    fzf
  ];

  # Ensure gio-unix-2.0 headers are found
  NIX_CFLAGS_COMPILE = "-I${glib.dev}/include/gio-unix-2.0";

  mesonFlags = [
    "-Dsystemd_user_unit_dir=${placeholder "out"}/lib/systemd/user"
    "-Dtests=false"
    "-Dgtk_doc=false"
    "-Dman=false"
  ];

  meta = with lib; {
    description = "On-screen keyboard for Phosh with word completion and cursor navigation";
    homepage = "https://gitlab.gnome.org/World/Phosh/stevia";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "phosh-osk-stevia";
  };
}
