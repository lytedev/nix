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
      # Set Ghostty as default terminal emulator
      environment.etc."xdg/kdeglobals".text = lib.mkDefault ''
        [General]
        TerminalApplication=ghostty
        TerminalService=com.mitchellh.ghostty.desktop
      '';

      # Window rules: no titlebar/frame for Ghostty
      environment.etc."xdg/kwinrulesrc".text = lib.mkDefault ''
        [1]
        Description=Ghostty no titlebar
        noborder=true
        noborderrule=2
        wmclass=com.mitchellh.ghostty
        wmclasscomplete=false
        wmclassmatch=1

        [General]
        count=1
        rules=1
      '';

      environment.etc."xdg/kwinrc".text = lib.mkDefault ''
        [Wayland]
        InputMethod=${pkgs.kdePackages.plasma-keyboard}/share/applications/org.kde.plasma.keyboard.desktop
        VirtualKeyboardEnabled=true

        [NightColor]
        Active=true
        NightTemperature=3000

        [Desktops]
        Number=4
        Rows=1
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

      # Shared plasma config dotfiles
      lyte.userSymlinks = {
        ".config/kdeglobals" = "${config.lyte.dotfilesPath}/plasma/kdeglobals";
        ".config/kcminputrc" = "${config.lyte.dotfilesPath}/plasma/kcminputrc";
        ".config/plasmanotifyrc" = "${config.lyte.dotfilesPath}/plasma/plasmanotifyrc";
        ".config/ksmserverrc" = "${config.lyte.dotfilesPath}/plasma/ksmserverrc";
        ".local/share/color-schemes/AyuDark.colors" = "${config.lyte.dotfilesPath}/plasma/AyuDark.colors";
        ".local/share/color-schemes/AyuLight.colors" = "${config.lyte.dotfilesPath}/plasma/AyuLight.colors";
        ".config/plasma-org.kde.plasma.desktop-appletsrc" =
          "${config.lyte.dotfilesPath}/plasma/plasma-org.kde.plasma.desktop-appletsrc";
        ".config/mimeapps.list" = "${config.lyte.dotfilesPath}/plasma/mimeapps.list";
        ".config/kglobalshortcutsrc" = "${config.lyte.dotfilesPath}/plasma/kglobalshortcutsrc";
      };
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
