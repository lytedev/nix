{
  pkgs,
  lib,
  config,
  options,
  ...
}:
let
  hasPlasmaLoginManager = options.services.displayManager ? plasma-login-manager;
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
      xdg.portal.extraPortals = with pkgs.kdePackages; [ xdg-desktop-portal-kde ];

      programs.kdeconnect.enable = true;
      services.xserver.enable = true;

      services.desktopManager.plasma6.enable = true;
      programs.dconf.enable = true;

      # Enable virtual keyboard (plasma-keyboard) in KWin
      # plasma-keyboard is KDE's native Qt6 virtual keyboard for Plasma 6.
      # It wraps qtvirtualkeyboard and speaks the Wayland input-method protocol.
      # KWin's KCM discovers it via X-KDE-Wayland-VirtualKeyboard=true in its .desktop file.
      # The kwinrc InputMethod key must point to the .desktop file path.
      environment.etc."xdg/kwinrc".text = lib.mkDefault ''
        [Wayland]
        InputMethod=${pkgs.kdePackages.plasma-keyboard}/share/applications/org.kde.plasma.keyboard.desktop
        VirtualKeyboardEnabled=true
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

        kdePackages.plasma-keyboard
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
    })

    (
      if hasPlasmaLoginManager then
        lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
          services.displayManager.plasma-login-manager.enable = true;
        }
      else
        lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
          services.displayManager.sddm.enable = true;
        }
    )
  ];
}
