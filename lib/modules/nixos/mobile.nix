{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lyte.mobile;
in
{
  options = {
    lyte = {
      mobile = {
        enable = lib.mkEnableOption "Enable mobile (Phosh) configuration for phones";
        user = lib.mkOption {
          type = lib.types.str;
          default = "daniel";
          description = "The user to run the Phosh session";
        };
        scale = lib.mkOption {
          type = lib.types.float;
          default = 1.5;
          description = "Display scale factor (1.5 recommended for PinePhone, 2.0 is default)";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Allow olm (used by chatty for Matrix) - it has known vulnerabilities but is needed
    nixpkgs.config.permittedInsecurePackages = [
      "olm-3.2.16"
    ];

    # Phosh desktop environment
    services.xserver.desktopManager.phosh = {
      enable = true;
      user = cfg.user;
      group = "users";
      phocConfig = {
        xwayland = "immediate"; # better x11 app compat
        outputs = {
          DSI-1 = {
            scale = cfg.scale;
          };
        };
      };
    };

    # Phone calling support
    programs.calls.enable = true;

    # ModemManager with quick suspend/resume for better call handling
    systemd.services.ModemManager.serviceConfig.ExecStart = [
      ""
      "${pkgs.modemmanager}/sbin/ModemManager --test-quick-suspend-resume"
    ];

    # Mobile hardware support
    hardware.sensor.iio.enable = true;
    services.geoclue2.enable = true;

    # feedbackd for haptic feedback (enabled by phosh, but we configure the profile)
    # Use `gsettings set org.sigxcpu.feedbackd profile silent` to disable vibration
    # Or use the feedbackd-toggle script we provide
    programs.feedbackd.enable = true;

    # Pipewire for audio
    services.pipewire.enable = true;

    # Mobile apps
    environment.systemPackages = with pkgs; [
      # Browser
      firefox

      # Communication
      chatty # SMS/MMS messaging
      gnome-contacts # Contact management (works with evolution-data-server)

      # Email
      geary # Mobile-friendly email client

      # Camera
      megapixels

      # Terminal
      ghostty

      # Fonts
      iosevkaLyteTerm

      # Utilities
      squeekboard # on-screen keyboard (comes with phosh but explicit)

      # Vibrator control script
      (writeShellScriptBin "vibrator-toggle" ''
        #!/usr/bin/env bash
        # Toggle feedbackd haptic feedback profile between full and silent
        current=$(${pkgs.glib}/bin/gsettings get org.sigxcpu.feedbackd profile 2>/dev/null || echo "'full'")
        if [ "$current" = "'silent'" ]; then
          ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
          echo "Vibration enabled (full)"
        else
          ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
          echo "Vibration disabled (silent)"
        fi
      '')

      (writeShellScriptBin "vibrator-off" ''
        ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile silent
        echo "Vibration disabled"
      '')

      (writeShellScriptBin "vibrator-on" ''
        ${pkgs.glib}/bin/gsettings set org.sigxcpu.feedbackd profile full
        echo "Vibration enabled"
      '')
    ];

    # Fonts
    fonts.packages = [
      pkgs.iosevkaLyteTerm
      (
        if builtins.hasAttr "nerd-fonts" pkgs then
          pkgs.nerd-fonts.symbols-only
        else
          (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      )
    ];

    # Qt apps should use wayland
    environment.sessionVariables = {
      QT_QPA_PLATFORM = "wayland";
    };

    # XDG portal for desktop integration
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
  };
}
