{ nixpkgs, ... }:
{
  style = {
    colors = (import ./colors.nix { inherit (nixpkgs) lib; }).schemes.catppuccin-mocha-sapphire;

    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };
  };

  /*
    moduleArgs = {
      # inherit style;
      inherit helix slippi hyprland hardware disko home-manager;
      inherit (outputs) nixosModules homeManagerModules diskoConfigurations overlays;
    };
  */

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev";
}
