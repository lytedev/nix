{nixpkgs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev:
    import ../packages {
      pkgs = import nixpkgs {inherit (final) system;};
    };

  /*
  This one contains whatever you want to overlay
  You can change versions, add patches, set compilation flags, anything really.
  https://nixos.wiki/wiki/Overlays
  */
  modifications = final: prev: {
    /*
    final.fprintd = prev.fprintd.overrideAttrs {
      # Source: https://github.com/NixOS/nixpkgs/commit/87ca2dc071581aea0e691c730d6844f1beb07c9f
      mesonCheckFlags = [
        # PAM related checks are timing out
        "--no-suite"
        "fprintd:TestPamFprintd"
      ];
    };
    */
  };

  /*
  When applied, the unstable nixpkgs set (declared in the flake inputs) will
  be accessible through 'pkgs.unstable'
  */
  unstable-packages = final: _prev: {
    unstable = import nixpkgs {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
