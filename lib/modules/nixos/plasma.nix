{
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = with self.outputs.nixosModules; [
    pipewire
  ];

  programs.kdeconnect.enable = true;
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    # package = lib.mkForce pkgs.kdePackages.sddm;
    settings = { };
    # theme = "";
    enableHidpi = true;
    wayland = {
      enable = true;
      compositor = "weston";
    };
  };

  services.desktopManager.plasma6.enable = true;
  programs.dconf.enable = true;

  services.xrdp.enable = false;
  services.xrdp.defaultWindowManager = "plasma";
  services.xrdp.openFirewall = false;

  environment.systemPackages = with pkgs; [
    wl-clipboard
    inkscape
    krita
    noto-fonts
    vlc
    wl-clipboard

    kdePackages.qtvirtualkeyboard
    maliit-keyboard
    maliit-framework

    kdePackages.kate
    kdePackages.kcalc
    kdePackages.filelight
    kdePackages.krdc
    kdePackages.krfb
    kdePackages.kclock
    kdePackages.kweather
    kdePackages.ktorrent
    kdePackages.kdeplasma-addons

    unstable-packages.kdePackages.krdp

    /*
      kdePackages.kdenlive
      kdePackages.merkuro
      kdePackages.neochat
      kdePackages.kdevelop
      kdePackages.kdialog
    */
  ];

  programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
}
