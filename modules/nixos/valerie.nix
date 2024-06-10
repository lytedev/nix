{
  pkgs,
  inputs,
  outputs,
  ...
}: let
  inherit (pkgs) system;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs system;
      inherit (outputs) colors font;
    };
    users.valerie = {
      # accounts.email.accounts = {
      # primary = {
      # primary = true;
      # address = "";
      # };
      # };

      home = {
        username = "valerie";
        homeDirectory = "/home/valerie";
      };

      imports = with outputs.homeManagerModules; [
        common
      ];
    };
  };
}
