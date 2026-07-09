{
  pkgs,
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.lyte.desktop;
  types = lib.types;
  dotfilesPath = config.lyte.dotfilesPath;
  danielHome = config.lyte.userHome;
  voxtypePkg = if cfg.voxtype.gpu then pkgs.voxtype-vulkan else pkgs.voxtype;
in
{
  options = {
    lyte = {
      desktop = {
        enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
        gnome.enable = lib.mkOption {
          default = false;
          example = true;
          description = "Enable GNOME desktop configuration and applications";
          type = types.bool;
        };
        cosmic.enable = lib.mkEnableOption "Enable Cosmic desktop configuration and applications";
        plasma.enable = lib.mkOption {
          default = false;
          example = true;
          description = "Enable Plasma desktop configuration and applications";
          type = types.bool;
        };
        niri.enable = lib.mkOption {
          default = config.lyte.desktop.enable;
          description = "Enable niri configuration and applications";
          type = types.bool;
          example = true;
        };
        greeter.enable = lib.mkOption {
          default =
            config.lyte.desktop.enable && config.lyte.desktop.niri.enable && !config.lyte.desktop.plasma.enable;
          description = ''
            Enable the greetd + ReGreet greeter (a minimal niri session running
            ReGreet plus a wvkbd on-screen keyboard). Defaults on for niri
            desktop hosts that don't run Plasma; Plasma hosts get
            plasma-login-manager/sddm from plasma.nix instead.
          '';
          type = types.bool;
          example = true;
        };
        niri.shell = lib.mkOption {
          default = "dms";
          description = "Which Quickshell-based desktop shell to run under niri";
          type = types.enum [
            "noctalia"
            "dms"
            "none"
          ];
        };
        niri.osk = lib.mkOption {
          default = "none";
          description = ''
            On-screen keyboard to run alongside niri (for touchscreens / 2-in-1s).

            - "wvkbd": uses wlr-virtual-keyboard-v1 only (no input-method
              dependency). Reliably renders on niri. Toggle via SIGRTMIN+8.
              No auto-show on text entry.
            - "squeekboard": speaks input-method-v2 and *tries* to auto-show
              on text-input-v3 focus. niri's text-input plumbing is reportedly
              flaky, and SetVisible without an active input-method client
              often commits a 0-height surface. Pick this if you specifically
              want auto-show and are willing to debug.

            `osk-toggle` is installed in either case to give you a manual
            toggle command (used by the niri keybind and the DMS bar plugin).
          '';
          type = types.enum [
            "wvkbd"
            "squeekboard"
            "none"
          ];
        };
        zen.enable = lib.mkOption {
          type = types.bool;
          default = cfg.enable && !cfg.firefox.mobile;
          description = "Enable Zen Browser with profile setup (the default desktop browser)";
        };
        firefox = {
          enable = lib.mkOption {
            type = types.bool;
            default = cfg.firefox.mobile;
            description = ''
              Enable Firefox with profile setup. Replaced by Zen Browser as the
              desktop default; still used for the mobile profile and kept as an
              opt-in escape hatch (e.g. the steamdeck Hearth kiosk).
            '';
          };
          mobile = lib.mkEnableOption "Use mobile Firefox profile instead of desktop";
        };
        voxtype.model = lib.mkOption {
          type = types.str;
          default = "base.en";
          description = "Whisper model for voxtype (e.g. base.en, large-v3-turbo)";
        };
        voxtype.gpu = lib.mkOption {
          type = types.bool;
          default = false;
          example = true;
          description = ''
            Use the Vulkan (GGML_VULKAN) whisper build of voxtype for
            GPU-accelerated transcription. Verified on dragon (RX 6700 XT /
            RADV): large-v3-turbo transcribes a few seconds of audio in ~2s
            on GPU vs minutes on CPU. Needs a Vulkan-capable GPU with the
            ICD from hardware.graphics.enable; falls back to CPU at runtime
            if no Vulkan device is found.
          '';
        };
        music.enable = lib.mkEnableOption "Enable music listening applications";
        displaylink.enable = lib.mkEnableOption ''
          DisplayLink USB graphics support (evdi DKMS module + the proprietary
          DisplayLinkManager service). Needed for USB-attached DisplayLink
          monitors, USB-C docks with embedded DL chips, and Logitech Tap
          (which presents its 10.1" panel as 17e9:ff13 over DisplayLink).

          The displaylink package is unfree and EULA-gated: the source zip is
          not on cache.nixos.org and must be prefetched once per host before
          first build:

            nix-prefetch-url --name displaylink-620.zip \
              https://www.synaptics.com/sites/default/files/exe_files/2025-09/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.2-EXE.zip

          (URL/version updates over time; the build error message will print
          the current correct one.)
        '';
        easyeffects = {
          enable = lib.mkEnableOption "Enable EasyEffects audio processing";
          preset = lib.mkOption {
            type = types.str;
            default = "";
            description = "EasyEffects preset to load";
          };
          presetsSource = lib.mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to EasyEffects presets directory (e.g. from fetchGit)";
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      boot.loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;
        systemd-boot.enable = lib.mkDefault true;
      };

      lyte.desktop.music.enable = lib.mkDefault true;

      services.xserver = {
        autoRepeatDelay = lib.mkDefault 200;
        autoRepeatInterval = lib.mkDefault 10;
      };

      services.pipewire.enable = true;
      environment.systemPackages = with pkgs; [
        pavucontrol
        pulsemixer
        libnotify
        wl-clipboard
        xdg-terminal-exec
        squashfsTools
        fractal
        (symlinkJoin {
          name = "element-desktop-wrapped";
          paths = [ element-desktop ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/element-desktop \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libsecret ]}"
          '';
        })

        # Desktop fonts and tools
        (
          if builtins.hasAttr "nerd-fonts" pkgs then
            (nerd-fonts.symbols-only)
          else
            (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
        )
        iosevkaLyteTerm
        spicetify-cli
        bibata-cursors

        # Ghostty
        ghostty

        # Audio recording (used by Claude Code /voice)
        sox

        # Voice-to-text
        voxtypePkg
        voxtype-osd-gtk4
        (pkgs.makeDesktopItem {
          name = "voxtype-toggle";
          desktopName = "Voxtype Toggle Recording";
          exec = "${voxtypePkg}/bin/voxtype record toggle";
          noDisplay = true;
          extraConfig."X-KDE-GlobalAccel-CommandShortcut" = "true";
        })
      ];

      fonts.packages = [
        (
          if builtins.hasAttr "nerd-fonts" pkgs then
            (pkgs.nerd-fonts.symbols-only)
          else
            (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
        )
        pkgs.iosevkaLyteTerm
        # Proportional UI sans (the GTK font-name below is Inter). Adwaita fonts too,
        # so GNOME's default "Adwaita Sans" also resolves (was falling back to DejaVu).
        pkgs.inter
        pkgs.adwaita-fonts
      ];

      fonts.fontDir.enable = true;

      xdg.portal.enable = true;
      xdg.mime.defaultApplications =
        let
          # zen-browser's default (beta) channel ships zen-beta.desktop
          browserDesktopFile = if cfg.zen.enable then "zen-beta.desktop" else "firefox.desktop";
        in
        {
          "x-scheme-handler/http" = browserDesktopFile;
          "x-scheme-handler/https" = browserDesktopFile;
          "text/html" = browserDesktopFile;
          "application/xhtml+xml" = browserDesktopFile;
        };

      hardware.graphics.enable = true;

      services.flatpak.enable = true;
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", MODE="0664", GROUP="dialout"
      '';
      programs.appimage = {
        enable = true;
        binfmt = true;
      };
      services.printing.enable = true;
      programs.virt-manager.enable = config.virtualisation.libvirtd.enable;

      # Cursor and GTK theme
      environment.sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "40";
        MOZ_ENABLE_WAYLAND = "1";
      };

      # Voice-to-text daemon (push-to-talk via Super+V, bound in the niri
      # config; the KDE global shortcut in plasma/kglobalshortcutsrc covers
      # any Plasma session). The daemon spawns its OSD launcher which picks
      # voxtype-osd-gtk4 from PATH — without it there is no on-screen
      # recording/transcribing indicator. `which` is required for voxtype's
      # output-method detection (see the overlay comment).
      #
      # No WAYLAND_DISPLAY is set here on purpose: the compositor session
      # imports the correct value into the systemd user manager. A hardcoded
      # value goes stale across compositor changes (a Plasma-era wayland-0
      # drop-in silently broke all text output under niri, which is wayland-1).
      systemd.user.services.voxtype = {
        description = "Voxtype push-to-talk voice-to-text";
        wantedBy = [ "graphical-session.target" ];
        after = [ "pipewire.service" ];
        partOf = [ "graphical-session.target" ];
        path = with pkgs; [
          which
          wtype
          dotool
          ydotool
          wl-clipboard
          libnotify
          voxtype-osd-gtk4
        ];
        environment.VOXTYPE_MODEL = cfg.voxtype.model;
        serviceConfig = {
          ExecStart = "${voxtypePkg}/bin/voxtype --no-hotkey daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # Symlinks for desktop configs
      lyte.userSymlinks = {
        ".config/ghostty" = "${dotfilesPath}/ghostty";
        ".local/share/fonts" = "/run/current-system/sw/share/X11/fonts";
      };

      # Cursor theme index, GTK settings, voxtype config
      lyte.userFiles = {
        ".icons/default/index.theme" = ''
          [Icon Theme]
          Name=Default
          Comment=Default Cursor Theme
          Inherits=Bibata-Modern-Classic
        '';
        ".config/gtk-3.0/settings.ini" = ''
          [Settings]
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=40
        '';
        ".config/gtk-4.0/settings.ini" = ''
          [Settings]
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=40
        '';
      };
    })

    # Zen Browser profile setup. The flake's package is XDG-aware: profiles
    # live under ~/.config/zen (verified by the flake's own VM tests), not
    # upstream's legacy ~/.zen. No userChrome.css here — Zen ships its own
    # heavily customized chrome and the Firefox Ayu theme would fight it.
    (lib.mkIf (cfg.enable && cfg.zen.enable) {
      environment.systemPackages = [ pkgs.zen-browser ];

      lyte.userFiles.".config/zen/profiles.ini" = ''
        [General]
        StartWithLastProfile=1

        [Profile0]
        Name=primary
        IsRelative=1
        Path=primary
        Default=1
      '';

      lyte.userSymlinks = {
        ".config/zen/primary/user.js" = "${dotfilesPath}/zen/user.js";
      };
    })

    # Firefox profile setup
    (lib.mkIf (cfg.enable && cfg.firefox.enable) {
      environment.systemPackages = with pkgs; [
        firefox
        pywal
        pywalfox-native
      ];

      lyte.userFiles.".mozilla/firefox/profiles.ini" = ''
        [General]
        StartWithLastProfile=1

        [Profile0]
        Name=primary
        IsRelative=1
        Path=primary
        Default=1
      '';

      lyte.userSymlinks = lib.mkIf (!cfg.firefox.mobile) {
        ".mozilla/firefox/primary/user.js" = "${dotfilesPath}/firefox/user.js";
        ".mozilla/firefox/primary/chrome/userChrome.css" = "${dotfilesPath}/firefox/userChrome.css";
      };
    })

    (lib.mkIf (cfg.enable && cfg.music.enable) {
      environment.systemPackages = with pkgs; [
        spotify-qt
        librespot
      ];
    })

    # Mobile Firefox profile override
    (lib.mkIf (cfg.enable && cfg.firefox.enable && cfg.firefox.mobile) {
      lyte.userSymlinks = {
        ".mozilla/firefox/primary/user.js" = "${dotfilesPath}/firefox-mobile/user.js";
        ".mozilla/firefox/primary/chrome/userChrome.css" = "${dotfilesPath}/firefox-mobile/userchrome.css";
        ".mozilla/firefox/primary/chrome/userContent.css" =
          "${dotfilesPath}/firefox-mobile/usercontent.css";
      };
    })

    # EasyEffects
    (lib.mkIf cfg.easyeffects.enable {
      environment.systemPackages = [ pkgs.easyeffects ];

      systemd.user.services.easyeffects = {
        description = "EasyEffects audio processing";
        wantedBy = [ "graphical-session.target" ];
        after = [ "pipewire.service" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart =
            "${pkgs.easyeffects}/bin/easyeffects --gapplication-service"
            + lib.optionalString (cfg.easyeffects.preset != "") " -l ${cfg.easyeffects.preset}";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      lyte.userSymlinks = lib.mkIf (cfg.easyeffects.presetsSource != null) {
        ".config/easyeffects/output" = toString cfg.easyeffects.presetsSource;
      };
    })

    # GPU: Intel
    (lib.mkIf (config.lyte.gpu == "intel") {
      hardware.graphics = {
        enable32Bit = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-ocl
          intel-vaapi-driver
        ];
      };
    })

    # GPU: AMD
    (lib.mkIf (config.lyte.gpu == "amd") {
      services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];
      hardware.graphics = {
        enable32Bit = true;
      };
      hardware.amdgpu.initrd.enable = lib.mkDefault true;
    })

    # DisplayLink USB graphics (opt-in; see option description for prefetch).
    (lib.mkIf cfg.displaylink.enable {
      services.xserver.videoDrivers = [ "displaylink" ];
    })
  ];
}
