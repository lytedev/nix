{
  nixpkgs,
  nixpkgs-unstable,
  ...
}@inputs:
let
  flakeOverlay =
    final: prev:
    let
      inherit (inputs) helix ghostty tuwunel;
      unstable-packages = import nixpkgs-unstable {
        system = final.system;
        config.allowUnfree = true;
      };
      stable-packages = import nixpkgs {
        system = final.system;
        config.allowUnfree = true;
      };
    in
    {
      inherit unstable-packages stable-packages;

      # force certain packages to always be unstable
      inherit (unstable-packages) jujutsu;

      # nixpkgs-unstable split zig's setup-hook into zig.hook, but that hook
      # unconditionally prepends default flags that conflict with ghostty's own.
      # provide the build/install phases directly instead.
      ghostty = (ghostty.outputs.packages.${prev.system}.default).overrideAttrs (old: {
        buildPhase = ''
          runHook preBuild
          ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
          export ZIG_GLOBAL_CACHE_DIR
          local flagsArray=("-j$NIX_BUILD_CORES")
          concatTo flagsArray zigBuildFlags zigBuildFlagsArray
          echoCmd 'zig build flags' "''${flagsArray[@]}"
          TERM=dumb zig build "''${flagsArray[@]}" --verbose
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
          export ZIG_GLOBAL_CACHE_DIR
          local flagsArray=("-j$NIX_BUILD_CORES")
          concatTo flagsArray zigBuildFlags zigBuildFlagsArray zigInstallFlags zigInstallFlagsArray
          flagsArray+=("--prefix" "$out")
          echoCmd 'zig install flags' "''${flagsArray[@]}"
          TERM=dumb zig build install "''${flagsArray[@]}" --verbose
          runHook postInstall
        '';
      });
      helix = helix.outputs.packages.${prev.system}.default;

      iosevkaLyteTerm = inputs.iosevka-lyte.outputs.packages.${prev.system}.default;
      matrix-tuwunel = tuwunel.packages.${prev.system}.default;

      mautrix-slack = (
        prev.mautrix-slack.override {
          buildGoModule =
            args:
            prev.buildGoModule (
              args
              // {
                src = prev.fetchFromGitHub {
                  owner = "lytedev";
                  repo = "mautrix-slack";
                  rev = "organize-channels-by-type";
                  hash = "sha256-pI98vqrCMbgiyOMHzoGjGYsvnLMFS7L9Mq9zbjwFa4E=";
                };
                vendorHash = "sha256-f4tZB4UR+ZHvdcawLWcywCCeGi3WErjCgkcf7tM9XtE=";
                version = "25.11-organize-channels-by-type";
                doInstallCheck = false;
              }
            );
        }
      );

      # use the baseline (no-AVX2) bun binary so builds work on older CPUs
      # (e.g., beefcake's Xeon E5-2680 v2 which only has AVX, not AVX2)
      bun =
        let
          baselineHashes = {
            "1.3.3" = "sha256-KB5sutlp6y9e9XJMbLoB2kDNX+rW+CksUO1gvU26eK4=";
            "1.3.9" = "sha256-EE1NA39LNeECFcBQfhd5aR85xXvZHd7v4RyteB4/xLk=";
          };
        in
        prev.bun.overrideAttrs (
          old:
          if prev.stdenv.hostPlatform.isx86_64 then
            {
              src = prev.fetchurl {
                url = "https://github.com/oven-sh/bun/releases/download/bun-v${old.version}/bun-linux-x64-baseline.zip";
                hash =
                  baselineHashes.${old.version}
                    or (throw "bun-baseline: no hash for v${old.version}; add it to baselineHashes in lib/overlays/default.nix");
              };
            }
          else
            { }
        );

      opencode = prev.opencode.overrideAttrs (_: {
        version = "1.2.22";
        src = prev.fetchFromGitHub {
          owner = "anomalyco";
          repo = "opencode";
          tag = "v1.2.22";
          hash = "sha256-fSSXUPfvhlWb5YEtW+bbi2mJaOV4Cdx3hbp6lnysxuo=";
        };
        node_modules = prev.opencode.node_modules.overrideAttrs (_: {
          src = prev.fetchFromGitHub {
            owner = "anomalyco";
            repo = "opencode";
            tag = "v1.2.22";
            hash = "sha256-fSSXUPfvhlWb5YEtW+bbi2mJaOV4Cdx3hbp6lnysxuo=";
          };
          outputHash = "sha256-U0DRfGsk6SeFqh8DuUsEQ/KmfTokNbr29RSxKgbdqG0=";
        });
      });

      bitwarden-desktop = prev.bitwarden-desktop.overrideAttrs (old: {
        preBuild = ''
          ${old.preBuild}
          pushd apps/desktop/desktop_native/proxy
          cargo build --bin desktop_proxy --release
          popd
        '';

        postInstall = ''
          mkdir -p $out/bin
          cp -r apps/desktop/desktop_native/target/release/desktop_proxy $out/bin
          mkdir -p $out/lib/mozilla/native-messaging-hosts
          substituteAll ${../../packages/bitwarden.json} $out/lib/mozilla/native-messaging-hosts/com.8bit.bitwarden.json
        '';
      });
    }
    // (import ../../packages { pkgs = final; });
in
{
  default = flakeOverlay;
  forSelf = flakeOverlay;
}
