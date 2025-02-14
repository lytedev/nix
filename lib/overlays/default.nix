{
  self,
  nixpkgs,
  nixpkgs-unstable,
  ...
} @ inputs: {
  default = final: _prev: {
    overlays = with self.overlays; [
      additions
      modifications
      unstable-packages
    ];
  };

  additions = final: prev: (prev // self.outputs.packages.${prev.system});

  modifications = final: prev: let
    inherit (inputs) helix ghostty;
  in {
    ghostty = ghostty.outputs.packages.${prev.system}.default;
    helix = helix.outputs.packages.${prev.system}.default;
    bitwarden = self.outputs.packages.${prev.system}.bitwarden;
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
