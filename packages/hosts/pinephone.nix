{
  config,
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "25.11";

  # olm is used by chatty for Matrix (not SMS) - allow despite deprecation
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services.xserver.desktopManager.phosh = {
    enable = true;
    user = "daniel";
    group = "users";
    phocConfig.xwayland = "immediate"; # better X11 app compat
  };

  # GPU/display
  hardware.graphics.enable = true;

  mobile.beautification = {
    silentBoot = false; # show boot messages
    splash = true;
  };

  # Stage-1 SSH for debugging (dropbear, passwordless root)
  mobile.boot.stage-1.ssh.enable = true;

  # Include firmware in initrd so bluetooth driver can load it early
  mobile.boot.stage-1.firmware = [ config.mobile.device.firmware ];
  hardware.firmware = [ config.mobile.device.firmware ];

  hardware.sensor.iio.enable = true;
  hardware.bluetooth.enable = true;

  programs.calls.enable = true; # phone calls
  programs.dconf.enable = true; # required for squeekboard/phosh settings

  environment.systemPackages = with pkgs; [
    # Communication
    chatty # SMS/text messaging
    gnome-contacts # contact management

    # Email
    geary # mobile-friendly email client

    # Browser
    firefox

    # Terminal
    ghostty

    # Camera
    megapixels

    # Utilities
    gnome-clocks # clock/alarm app

    # Fonts
    iosevkaLyteTerm

    # Vibrator control scripts
    (writeShellScriptBin "vibrator-toggle" ''
      current=$(${glib}/bin/gsettings get org.sigxcpu.feedbackd profile 2>/dev/null || echo "'full'")
      if [ "$current" = "'silent'" ]; then
        ${glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
        echo "Vibration enabled (full)"
      else
        ${glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
        echo "Vibration disabled (silent)"
      fi
    '')
    (writeShellScriptBin "vibrator-off" ''
      ${glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
      echo "Vibration disabled"
    '')
    (writeShellScriptBin "vibrator-on" ''
      ${glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
      echo "Vibration enabled"
    '')
  ];

  # Fonts
  fonts.packages = with pkgs; [
    iosevkaLyteTerm
  ];

  # enable shell tools on the NixOS side
  lyte.shell.enable = true;

  # disable desktop features that don't apply to mobile
  lyte.desktop.enable = false;

  # pinephone-specific user group additions
  users.users.daniel.extraGroups = lib.mkAfter [
    "feedbackd"
  ];

  # home-manager configuration for daniel on pinephone
  home-manager.users.daniel = {
    lyte.shell.enable = true;
    lyte.desktop.enable = false;
    # btop rocm is x86_64 only
    programs.btop.package = lib.mkForce pkgs.btop;

    # enable dconf for phosh/squeekboard (normally enabled by lyte.desktop)
    dconf.enable = true;

    # Firefox with mobile-friendly settings - override the default "primary" profile
    programs.firefox = {
      enable = true;
      profiles.primary = lib.mkForce {
        id = 0;
        isDefault = true;
        settings = {
          # Touch-friendly settings
          "apz.allow_double_tap_zooming" = true;
          "apz.allow_zooming" = true;
          "dom.w3c_touch_events.enabled" = 1;

          # Performance for PinePhone (no GLES3)
          "gfx.webrender.force-disabled" = true;

          # UI
          "browser.toolbars.bookmarks.visibility" = "never";
          "general.smoothScroll" = true;
        };
        userChrome = ''
          /* Larger touch targets */
          #nav-bar toolbarbutton {
            min-width: 44px !important;
            min-height: 44px !important;
          }
          #TabsToolbar {
            visibility: collapse !important;
          }
        '';
        extraConfig = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        '';
      };
    };

    home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

    # enable on-screen keyboard (squeekboard) via dconf
    dconf.settings = {
      "org/gnome/desktop/a11y/applications" = {
        screen-keyboard-enabled = true;
      };
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    # squeekboard systemd service for phosh 0.50.0+
    # phosh OSK target wants mobi.phosh.OSK.service but squeekboard doesn't provide it
    systemd.user.services."mobi.phosh.OSK" = {
      Unit = {
        Description = "Squeekboard on-screen keyboard";
        PartOf = [ "mobi.phosh.OSK.target" ];
      };
      Service = {
        Type = "dbus";
        BusName = "sm.puri.OSK0";
        ExecStart = "${pkgs.squeekboard}/bin/squeekboard";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "mobi.phosh.OSK.target" ];
      };
    };
  };

  networking.hostName = "pinephone";
  networking.networkmanager.enable = true;

  # pinephone kernel doesn't support rpfilter, but we still want a firewall
  # mkForce needed to override tailscale's "loose" setting
  networking.firewall = {
    enable = true;
    checkReversePath = lib.mkForce false;
  };

  # tailscale for remote access (enabled via default module, explicit here for clarity)
  services.tailscale.enable = true;

  services.smartd.enable = lib.mkForce false;

  # slippi's gamecube adapter requires kernel modules - disable on mobile
  gamecube-controller-adapter = {
    enable = lib.mkForce false;
    overclocking-kernel-module.enable = lib.mkForce false;
  };
}
