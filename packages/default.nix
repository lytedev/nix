{pkgs, ...}: let
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix {};
in {
  inherit iosevkaLyteTerm;

  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };

  bitwarden = pkgs.bitwarden.overrideAttrs (old: {
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
      substituteAll ${./bitwarden.json} $out/lib/mozilla/native-messaging-hosts/com.8bit.bitwarden.json
    '';
  });
}
