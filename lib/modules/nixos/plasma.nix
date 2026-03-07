{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
    xdg.portal.extraPortals = with pkgs.kdePackages; [ xdg-desktop-portal-kde ];

    programs.kdeconnect.enable = true;
    services.xserver.enable = true;

    services.displayManager.plasma-login-manager.enable = true;
    services.desktopManager.plasma6.enable = true;
    programs.dconf.enable = true;

    # Enable virtual keyboard (qtvirtualkeyboard) in KWin
    environment.etc."xdg/kwinrc".text = lib.mkDefault ''
      [Wayland]
      VirtualKeyboardEnabled=true

      [Input]
      TabletMode=auto
    '';

    # services.xrdp.enable = false;
    # services.xrdp.defaultWindowManager = "plasma";
    # services.xrdp.openFirewall = false;

    environment.systemPackages = with pkgs; [
      wl-clipboard
      # inkscape
      # krita
      noto-fonts
      # vlc
      wl-clipboard

      kdePackages.qtvirtualkeyboard

      # kdePackages.kate
      # kdePackages.kcalc
      # kdePackages.filelight
      # kdePackages.krdc
      # kdePackages.krfb
      # kdePackages.kclock
      # kdePackages.kweather
      # kdePackages.ktorrent
      # kdePackages.kdeplasma-addons

      # unstable-packages.kdePackages.krdp

      /*
        kdePackages.kdenlive
        kdePackages.merkuro
        kdePackages.neochat
        kdePackages.kdevelop
        kdePackages.kdialog
      */
    ];

    programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
  };
}
