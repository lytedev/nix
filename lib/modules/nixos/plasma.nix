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
      networking.firewall = rec {
        allowedTCPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
        allowedUDPPortRanges = allowedTCPPortRanges;
      };

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

      # Common plasma desktop defaults (clock, launcher, pager, taskbar)
      # These act as XDG defaults — Plasma will use them for new profiles
      # but per-host layout (screens, panels, containments) is managed by Plasma itself
      environment.etc."xdg/plasma-org.kde.plasma.desktop-appletsrc".text = lib.mkDefault ''
        [Containments][2][Applets][21][Configuration][Appearance]
        dateFormat=isoDate
        showDate=true
        dateDisplayFormat=adaptiveLocaleShort
        fontWeight=400
        use24hFormat=2

        [Containments][2][Applets][3][Configuration][General]
        icon=nix-snowflake
        systemFavorites=suspend\\,hibernate\\,reboot\\,shutdown

        [Containments][2][Applets][4][Configuration][General]
        showOnlyCurrentScreen=true
        wrapPage=true

        [Containments][2][Applets][5][Configuration][General]
        launchers=applications:com.mitchellh.ghostty.desktop,preferred://browser,applications:systemsettings.desktop,preferred://filemanager

        [Containments][2][Applets][7][General]
        extraItems=org.kde.kdeconnect,org.kde.plasma.cameraindicator,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.notifications,org.kde.kscreen,org.kde.plasma.battery,org.kde.plasma.bluetooth,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.printmanager,org.kde.plasma.volume,org.kde.plasma.weather,org.kde.plasma.clipboard
        knownItems=org.kde.kdeconnect,org.kde.plasma.cameraindicator,org.kde.plasma.clipboard,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.notifications,org.kde.kscreen,org.kde.plasma.battery,org.kde.plasma.bluetooth,org.kde.plasma.brightness,org.kde.plasma.keyboardindicator,org.kde.plasma.keyboardlayout,org.kde.plasma.networkmanagement,org.kde.plasma.printmanager,org.kde.plasma.volume,org.kde.plasma.weather
        hiddenItems=org.kde.plasma.clipboard

        [Containments][2][Applets][7][Applets][20][Configuration][WeatherStation]
        placeDisplayName=Overland Park, Kansas, US
        placeInfo=place|Overland Park, Kansas, US|extra|US0KS0455;Overland Park
        provider=wettercom
      '';

      # Keyboard repeat, numlock, and trackpad defaults
      environment.etc."xdg/kcminputrc".text = lib.mkDefault ''
        [Keyboard]
        NumLock=0
        RepeatDelay=200
        RepeatRate=80

        [Touchpad]
        NaturalScroll=true
        TapToClick=true
        DisableWhileTyping=true
      '';

      # Screen lock after 10 minutes, DPMS standby after 15 minutes
      environment.etc."xdg/kscreenlockerrc".text = lib.mkDefault ''
        [Daemon]
        Autolock=true
        Timeout=10
        LockOnResume=true
      '';

      environment.etc."xdg/powermanagementprofilesrc".text = lib.mkDefault ''
        [AC][DPMSControl]
        idleTime=900
        lockBeforeTurnOff=0

        [Battery][DPMSControl]
        idleTime=600
        lockBeforeTurnOff=0
      '';

      # Electron/Chromium native Wayland support
      environment.sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        NIXOS_OZONE_WL = "1";
      };

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

        [Compositing]
        AllowTearing=true

        [MouseBindings]
        CommandAll1=Move
        CommandAll2=Toggle raise and lower
        CommandAll3=Resize
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
        ".config/plasmanotifyrc" = "${config.lyte.dotfilesPath}/plasma/plasmanotifyrc";
        ".config/ksmserverrc" = "${config.lyte.dotfilesPath}/plasma/ksmserverrc";
        ".local/share/color-schemes/AyuDark.colors" = "${config.lyte.dotfilesPath}/plasma/AyuDark.colors";
        ".local/share/color-schemes/AyuLight.colors" = "${config.lyte.dotfilesPath}/plasma/AyuLight.colors";
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
