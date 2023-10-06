{
  outputs,
  pkgs,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    common
  ];

  programs.fish = {
    shellAliases = {
      sctl = "sudo systemctl";
      bt = "bluetoothctl";
      pa = "pulsemixer";
      sctlu = "systemctl --user";
    };
  };

  home.packages = [
    (pkgs.buildEnv {
      name = "my-linux-scripts";
      paths = [./scripts/linux];
    })
  ];
}
