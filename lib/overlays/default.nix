{
  nixpkgs,
  nixpkgs-unstable,
  ...
}@inputs:
rec {
  default = final: _prev: {
    overlays = [
      additions
      modifications
      unstable-packages
      stable-packages
    ];
  };

  forSelf = default;

  additions = final: prev: (import ../../packages { pkgs = prev; });

  modifications =
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
    };

  unstable-packages = final: _prev: {
    unstable-packages = import nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  stable-packages = final: _prev: {
    stable-packages = import nixpkgs {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
