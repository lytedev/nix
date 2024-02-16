{
  config,
  outputs,
  ...
}: {
  # a minimal, familiar setup that I can bootstrap atop
  imports = with outputs.nixosModules; [
    # may need to be tweaked based on the machine's paritioning scheme
    outputs.diskoConfigurations.standard
    desktop-usage
    wifi
  ];

  networking.hostName = config.home-manager.users.daniel.home.username;

  # TODO: may not work for non-UEFI?
  boot.loader.systemd-boot.enable = true;
}
