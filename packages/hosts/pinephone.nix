# PinePhone configuration
# Uses lyte.mobile module for common mobile/phosh and mobile-nixos settings
{
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "25.11";

  # Enable the mobile module for phosh, apps, fonts, mobile-nixos settings, etc.
  lyte.mobile = {
    enable = true;
    user = "daniel";
    scale = 1.5; # 1.5 recommended for PinePhone
  };

  # GPU/display
  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;

  # dconf required for squeekboard/phosh settings
  programs.dconf.enable = true;

  # Additional packages specific to this host
  environment.systemPackages = with pkgs; [
    gnome-clocks # clock/alarm app
  ];

  # Shell tools on the NixOS side
  lyte.shell.enable = true;

  # Disable desktop features that don't apply to mobile
  lyte.desktop.enable = false;

  # pinephone-specific user group additions
  users.users.daniel.extraGroups = lib.mkAfter [
    "feedbackd"
  ];

  # home-manager configuration for daniel on pinephone
  home-manager.users.daniel = {
    lyte.shell.enable = true;
    lyte.desktop.enable = false;
    lyte.mobile.enable = true;

    # btop rocm is x86_64 only
    programs.btop.package = lib.mkForce pkgs.btop;
  };

  networking.hostName = "pinephone";
  networking.networkmanager.enable = true;

  # pinephone kernel doesn't support rpfilter, but we still want a firewall
  # mkForce needed to override tailscale's "loose" setting
  networking.firewall = {
    enable = true;
    checkReversePath = lib.mkForce false;
  };

  # tailscale for remote access
  services.tailscale.enable = true;

  # SD card storage doesn't need SMART monitoring
  services.smartd.enable = lib.mkForce false;

  # slippi's gamecube adapter requires kernel modules - disable on mobile
  gamecube-controller-adapter = {
    enable = lib.mkForce false;
    overclocking-kernel-module.enable = lib.mkForce false;
  };
}
