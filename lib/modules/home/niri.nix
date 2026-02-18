{ inputs }:
{
  imports = [
    inputs.noctalia.homeModules.default
    (
      { config, ... }:
      {
        # symlink the config regardless
        home.file."${config.xdg.configHome}/niri" = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/niri";
        };
        home.file."${config.xdg.configHome}/ironbar" = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.lyte.flakePath}/dotfiles/ironbar";
        };
      }
    )
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.niri.enable) {
          # programs.niri.package = pkgs.niri-unstable;
          programs.noctalia-shell = {
            enable = true;
          };

          # Ensure niri config include files exist before starting niri
          systemd.user.services.niri-file-setup = {
            Unit = {
              Description = "Ensure niri config include files exist";
              Before = [ "niri.service" ];
              PartOf = [ "niri.service" ];
            };
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/touch ${config.xdg.configHome}/niri/noctalia.kdl ${config.xdg.configHome}/niri/host-specific.kdl'";
            };
            Install = {
              WantedBy = [ "niri.service" ];
            };
          };

          services.mako.enable = false;

          # Discord with Vencord for noctalia theming support
          programs.vesktop = {
            enable = true;
          };

          home.packages = with pkgs; [
            swayosd
            swaylock
            swayidle
            fuzzel
            brightnessctl
            xwayland-satellite
          ];

          # Configure swayidle for automatic locking and power management
          services.swayidle = {
            enable = true;
            events = {
              before-sleep = "${pkgs.bash}/bin/bash -c 'noctalia-shell ipc call lockScreen lock'";
              lock = "${pkgs.bash}/bin/bash -c 'noctalia-shell ipc call lockScreen lock'";
            };
            timeouts = [
              {
                timeout = 600; # 10 minutes
                command = "${pkgs.bash}/bin/bash -c 'noctalia-shell ipc call lockScreen lock'";
              }
              {
                timeout = 900; # 15 minutes
                command = "${pkgs.niri-unstable}/bin/niri msg action power-off-monitors";
              }
            ];
            systemdTarget = "niri.service";
          };
          dconf.settings = {
            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
            };
          };
          gtk.theme.name = "Adwaita-dark";
        };
      }
    )
  ];
}
