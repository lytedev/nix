{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  pam,
  libxcb,
  wayland,
  libclang,
  llvmPackages,
}:
rustPlatform.buildRustPackage {
  pname = "wden";
  version = "0.15.0";

  src = fetchFromGitHub {
    owner = "luryus";
    repo = "wden";
    rev = "0.15.0";
    hash = "sha256-fngriQcXffgaXG/1zzDseJBFxNJXUftatH4x+lKV6Yg=";
  };

  cargoHash = "sha256-kxiS2CYy8U/t8j6VxofnZEfMBoof/bvnEp+TLQcMOBU=";

  nativeBuildInputs = [ pkg-config ];

  LIBCLANG_PATH = "${libclang.lib}/lib";
  env.BINDGEN_EXTRA_CLANG_ARGS = toString (
    [
      "-I${pam}/include"
    ]
    ++ (builtins.map (a: "-isystem ${a}/include") [
      stdenv.cc.cc
      stdenv.cc.libc.dev
    ])
  );
  buildInputs = [
    pam
    libxcb
    wayland
  ];

  meta = with lib; {
    description = "Read-only TUI client for Bitwarden";
    homepage = "https://github.com/luryus/wden";
    license = licenses.mit;
    mainProgram = "wden";
  };
}
