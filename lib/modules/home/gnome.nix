{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.gnome.enable) {
    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "caps:ctrl_modifier" ];
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [ "<Shift><Control><Super>l" ]; # lock screen
          mic-mute = [ "<Shift><Super>v" ];
        };
        "org/gnome/desktop/default-applications/terminal" = {
          exec = "ghostty";
        };
        "org/gnome/desktop/peripherals/touchpad" = {
          disable-while-typing = false;
        };
        "org/gnome/desktop/peripherals/keyboard" = {
          # gnome key repeat
          repeat = true;
          repeat-interval = lib.hm.gvariant.mkUint32 10;
          delay = lib.hm.gvariant.mkUint32 200;
        };

        "org/gnome/desktop/wm/preferences" = {
          resize-with-right-button = true;
          # mouse-button-modifier = '<Super>'; # default
        };
        "org/gnome/desktop/wm/keybindings" = {
          minimize = [ "<Shift><Control><Super>h" ];
          show-desktop = [ "<Super>d" ];
          move-to-workspace-left = [ "<Super><Shift>h" ];
          move-to-workspace-right = [ "<Super><Shift>l" ];
          switch-to-workspace-left = [ "<Super><Control>h" ];
          switch-to-workspace-right = [ "<Super><Control>l" ];
          # mouse-button-modifier = '<Super>'; # default
        };
        "org/gnome/desktop/interface" = {
          show-battery-percentage = true;
          clock-show-weekday = true;
          # font-name = "IosevkaLyteTerm 12";
          # monospace-font-name = "IosevkaLyteTerm 12";
          # color-scheme = "prefer-dark"; # don't set this so we respect the current toggle
          # scaling-factor = 1.75;
        };
        "org/gnome/mutter" = {
          experimental-features = [
            "variable-refresh-rate"
            "scale-monitor-framebuffer"
            # "xwayland-native-scaling"
          ];
        };

        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = with pkgs.gnomeExtensions; [
            tiling-shell.extensionUuid
            appindicator.extensionUuid
            blur-my-shell.extensionUuid
            # gsconnect.extenstionUuid
          ];
        };

        "org/gnome/shell/extensions/tilingshell" = {
          inner-gaps = 8;
          outer-gaps = 8;
          window-border-width = 2;
          window-border-color = "rgba(116,199,236,0.47)";
          focus-window-right = [ "<Super>l" ];
          focus-window-left = [ "<Super>h" ];
          focus-window-up = [ "<Super>k" ];
          focus-window-down = [ "<Super>j" ];
        };
      };
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Common formats
        "application/zip" = "org.gnome.FileRoller.desktop";
        "application/x-tar" = "org.gnome.FileRoller.desktop";
        "application/gzip" = "org.gnome.FileRoller.desktop";
        "application/x-gzip" = "org.gnome.FileRoller.desktop";
        "application/x-bzip2" = "org.gnome.FileRoller.desktop";
        "application/x-xz" = "org.gnome.FileRoller.desktop";
        "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
        "application/x-rar" = "org.gnome.FileRoller.desktop";
        # Compressed tarballs
        "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-lzma-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-lz4-compressed-tar" = "org.gnome.FileRoller.desktop";
        # Modern/standalone compression
        "application/zstd" = "org.gnome.FileRoller.desktop";
        "application/x-lz4" = "org.gnome.FileRoller.desktop";
        "application/x-lzip" = "org.gnome.FileRoller.desktop";
        # Package formats (useful for inspection)
        "application/vnd.debian.binary-package" = "org.gnome.FileRoller.desktop";
        "application/x-rpm" = "org.gnome.FileRoller.desktop";
        "application/java-archive" = "org.gnome.FileRoller.desktop";
        # Other archive formats
        "application/x-cpio" = "org.gnome.FileRoller.desktop";
        "application/x-archive" = "org.gnome.FileRoller.desktop";
        "application/x-iso9660-image" = "org.gnome.FileRoller.desktop";
        "application/vnd.ms-cab-compressed" = "org.gnome.FileRoller.desktop";
        "application/x-xar" = "org.gnome.FileRoller.desktop";
        "application/x-lha" = "org.gnome.FileRoller.desktop";
      };
    };

    home = {
      packages = with pkgs.gnomeExtensions; [
        tiling-shell
        blur-my-shell
        appindicator
      ];
    };

    programs.gnome-shell = {
      enable = true;
      extensions = [
        { package = pkgs.gnomeExtensions.gsconnect; }
      ]
      ++ map (p: { package = p; }) (
        with pkgs.gnomeExtensions;
        [
          tiling-shell
          blur-my-shell
          appindicator
          gsconnect
        ]
      );
    };
  };
}
