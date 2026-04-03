{
  nixpkgs,
  nixpkgs-unstable,
  rust-overlay,
  ...
}@inputs:
let
  flakeOverlay =
    final: prev:
    let
      inherit (inputs)
        helix
        ghostty
        tuwunel
        firefox-nightly
        ;
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

      voxtype = inputs.voxtype.packages.${final.system}.default;

      # Override iamb with unreads fix PR #579
      iamb = prev.iamb.overrideAttrs (old: rec {
        version = "0.0.11-unreads-fix";
        src = final.fetchFromGitHub {
          owner = "VAWVAW";
          repo = "iamb";
          rev = "87a702d4a520d2c0ae54f9d76178f9f54e09b56e";
          hash = "sha256-ycKOIdoMcz9XfpdP4IwgvcgI763tlWoQRdCCGoWsysA=";
        };
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-uWYNFNoCiqw6gYuHZWmZmZVs7lKNvhzjwEyxgcbvv+8=";
        };
        doInstallCheck = false;
      });

      atuin =
        let
          rust-bin = rust-overlay.lib.mkRustBin { } unstable-packages;
          rustToolchain = rust-bin.stable."1.94.0".minimal;
          rustPlatform' = unstable-packages.makeRustPlatform {
            rustc = rustToolchain;
            cargo = rustToolchain;
          };
        in
        unstable-packages.callPackage (
          {
            fetchFromGitHub,
            installShellFiles,
            lib,
            stdenv,
            nixosTests,
            nix-update-script,
          }:
          rustPlatform'.buildRustPackage (finalAttrs: {
            pname = "atuin";
            version = "18.13.3";

            src = fetchFromGitHub {
              owner = "atuinsh";
              repo = "atuin";
              tag = "v${finalAttrs.version}";
              hash = "sha256-hLt6CDHEPV8BVpOADVn4bLNcBz89eC2jKtIexHG0yAY=";
            };

            cargoHash = "sha256-VYwzMnfc/a4Sghmr5oMfhvoMkaWlY4w4e4Flu8MWQg0=";

            # atuin 18.13 split the server into a separate crate/binary
            cargoBuildFlags = [
              "--package"
              "atuin"
              "--package"
              "atuin-server"
            ];
            buildNoDefaultFeatures = true;
            buildFeatures = [
              "client"
              "sync"
              "clipboard"
              "daemon"
              "hex"
            ];

            nativeBuildInputs = [ installShellFiles ];

            postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
              installShellCompletion --cmd atuin \
                --bash <($out/bin/atuin gen-completions -s bash) \
                --fish <($out/bin/atuin gen-completions -s fish) \
                --zsh <($out/bin/atuin gen-completions -s zsh)
            '';

            checkFlags = [
              "--skip=registration"
              "--skip=sync"
              "--skip=change_password"
              "--skip=multi_user_test"
            ];

            preCheck = ''
              export HOME=$(mktemp -d)
            '';

            passthru = {
              tests = {
                inherit (nixosTests) atuin;
              };
              updateScript = nix-update-script { };
            };

            meta = {
              description = "Replacement for a shell history which records additional commands context with optional encrypted synchronization between machines";
              homepage = "https://github.com/atuinsh/atuin";
              license = lib.licenses.mit;
              maintainers = with lib.maintainers; [
                SuperSandro2000
                sciencentistguy
                _0x4A6F
                rvdp
              ];
              mainProgram = "atuin";
            };
          })
        ) { };

      # bleeding-edge Firefox variants
      firefox-nightly = firefox-nightly.packages.${prev.system}.firefox-nightly-bin;
      inherit (unstable-packages) firefox-devedition-bin;

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
            "1.3.10" = "sha256-QSAajF7nSp3Lsc4loRBPH5KYOLV6hFqnjZg3mwznzeI=";
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

      opencode =
        let
          opencode-src = prev.fetchFromGitHub {
            owner = "lytedev";
            repo = "opencode";
            rev = "54a5ba7084ebf9e6cc255afbd00a984dc89261f9";
            hash = "sha256-qYEHiz6sQ56CJyYJglqSflu2SY2abLdgEqQ5NkUml24=";
          };
        in
        (final.callPackage "${opencode-src}/nix/opencode.nix" {
          node_modules = final.callPackage "${opencode-src}/nix/node_modules.nix" {
            rev = "54a5ba7";
          };
        }).overrideAttrs
          {
            postPatch = ''
              substituteInPlace packages/script/src/index.ts \
                --replace-fail 'throw new Error(`This script requires bun@''${expectedBunVersionRange}' \
                               'console.warn(`Warning: This script expects bun@''${expectedBunVersionRange}'
            '';
          };

      # Debounce tile editor toggle to prevent key-repeat from firing
      # toggle() multiple times while the main thread is blocked loading QML.
      kdePackages = prev.kdePackages // {
        kwin = prev.kdePackages.kwin.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ../../patches/kwin-tileseditor-double-toggle.patch ];
        });
      };

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
