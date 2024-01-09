{
  pkgs,
  lib,
  ...
}: {
  imports = [./pipewire.nix];

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = lib.mkDefault false;
  services.xserver.desktopManager.plasma5.enable = true;

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  programs.ssh.askPassword = "${pkgs.plasma5Packages.ksshaskpass}/bin/ksshaskpass";

  services.xserver.displayManager.defaultSession = "plasmawayland";

  programs.dconf.enable = true;

  # xdg.portal = {
  #   enable = true;
  #   wlr.enable = false;

  # extraPortals = with pkgs; [
  #   xdg-desktop-portal-kde
  # ];
  # };

  # hardware.pulseaudio.enable = false;
}
