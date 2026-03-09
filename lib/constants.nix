{ nixpkgs, ... }:
{
  style = {
    colors = (import ./colors.nix { inherit (nixpkgs) lib; }).schemes.catppuccin-mocha-sapphire;

    font = {
      name = "IosevkaLyteTerm";
      size = 12;
    };
  };

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev";
}
