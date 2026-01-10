{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook3,
  glib,
  gmobile,
  modemmanager,
  mobile-broadband-provider-info,
  systemd,
}:
let
  gvdb = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "GNOME";
    repo = "gvdb";
    rev = "4758f6fb7f889e074e13df3f914328f3eecb1fd3";
    hash = "sha256-4mqoHPlrMPenoGPwDqbtv4/rJ/uq9Skcm82pRvOxNIk=";
  };
in
stdenv.mkDerivation rec {
  pname = "cellbroadcastd";
  version = "0.0.3";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "devrtz";
    repo = "cellbroadcastd";
    rev = "v${version}";
    hash = "sha256-QMx/E631aWJIwvRDbzyrO9K+7xdd54ZbiE4Eoune3Co=";
  };

  postUnpack = ''
    # Place gvdb in subprojects directory for meson
    mkdir -p $sourceRoot/subprojects
    cp -r ${gvdb} $sourceRoot/subprojects/gvdb
    chmod -R u+w $sourceRoot/subprojects/gvdb
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gmobile
    modemmanager
    mobile-broadband-provider-info
    systemd
  ];

  mesonFlags = [
    "-Dsystemd_user_unit_dir=${placeholder "out"}/lib/systemd/user"
    "-Dintrospection=disabled"
  ];

  meta = with lib; {
    description = "Cell broadcast daemon for receiving emergency alerts and other cell broadcasts";
    homepage = "https://gitlab.freedesktop.org/devrtz/cellbroadcastd";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "cbcli";
  };
}
