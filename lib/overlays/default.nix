{
  nixpkgs,
  nixpkgs-unstable,
  ...
}@inputs:
let
  flakeOverlay =
    final: prev:
    let
      inherit (inputs) helix ghostty;
    in
    {
      ghostty = ghostty.outputs.packages.${prev.system}.default;
      helix = helix.outputs.packages.${prev.system}.default;

      bitwarden = prev.bitwarden.overrideAttrs (old: {
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
      unstable-packages = import nixpkgs-unstable {
        system = final.system;
        config.allowUnfree = true;
      };
      stable-packages = import nixpkgs {
        system = final.system;
        config.allowUnfree = true;
      };
    }
    // (import ../../packages { pkgs = prev; });
in
{
  default = flakeOverlay;
  forSelf = flakeOverlay;
}
