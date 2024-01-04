{
  outputs,
  flake,
  ...
}: {
  # a minimal, familiar setup that I can bootstrap atop
  imports = with outputs.nixosModules; [
    flake.diskoConfigurations.standard
    desktop-usage
    wifi
  ];

  boot.loader.systemd-boot.enable = true;
}
