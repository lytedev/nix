{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.lyte;
  flakePath = cfg.flakePath;
  danielHome = config.users.users.daniel.home;
in
{
  options = {
    lyte = {
      shell = {
        enable = lib.mkEnableOption "Enable my default shell configuration and applications";
        learn-jujutsu-not-git = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Soft-disable the 'git' command in an effort to force me to learn jujutsu (jj)";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.shell.enable {
    services.kanidm.enableClient = true;
    programs.nix-index.enable = true;
    programs.command-not-found.enable = false;
    services = {
      fwupd.enable = lib.mkDefault true;
    };
    users = {
      defaultUserShell = pkgs.fish;
    };
    programs = {
      fish = {
        enable = true;

        # Fish shell init (read from dotfiles at build time)
        shellInit = builtins.readFile ../../../dotfiles/fish/shellInit.fish;
        interactiveShellInit = builtins.readFile ../../../dotfiles/fish/interactiveShellInit.fish + ''

          # Shell integrations
          ${pkgs.atuin}/bin/atuin init fish --disable-up-arrow | source
          ${pkgs.direnv}/bin/direnv hook fish | source
          ${pkgs.fzf}/bin/fzf --fish | source
        '';

        shellAliases = {
          disks = "df -h && lsblk";
          sctl = "sudo systemctl";
          bt = "bluetoothctl";
          pa = "pulsemixer";
          pv = "pavucontrol";
          sctlu = "systemctl --user";
        }
        // lib.optionalAttrs cfg.shell.learn-jujutsu-not-git.enable {
          git = ''echo "use jj (jujutsu) instead of git, silly! (override with command git ...)"'';
        };
      };

      traceroute.enable = true;

      git = {
        enable = true;
        package = pkgs.gitFull;
        lfs.enable = true;
        config = {
          include.path = "${danielHome}/.config/git/config.local";
        };
      };
    };

    environment = {
      variables = {
        EDITOR = "hx";
        SYSTEMD_EDITOR = "hx";
        VISUAL = "hx";
        PAGER = "bat --style=plain";
        MANPAGER = "bat --style=plain";
      };
      sessionVariables = {
        TERMINAL = "ghostty";
      };
      systemPackages = with pkgs; [
        # CLI tools (also used in fish interactiveShellInit)
        atuin
        direnv
        fzf
        nix-direnv

        aria2
        bat
        bitwarden-cli
        bottom
        btop
        comma
        curl
        delta
        dnsutils
        doggo
        dua
        eza
        fd
        file
        gawk
        helix
        hexyl
        htop
        iftop
        inetutils
        iputils
        jq
        jujutsu
        killall
        nettools
        nil
        nixd
        nixfmt-rfc-style
        nmap
        pciutils
        ripgrep
        rsync
        sd
        senpai
        unixtools.xxd
        usbutils
        w3m
        xh
        zellij

        # Custom scripts
        (pkgs.buildEnv {
          name = "my-common-scripts";
          paths = [ ../home/scripts/common ];
        })
        (pkgs.buildEnv {
          name = "my-linux-scripts";
          paths = [ ../home/scripts/linux ];
        })
      ];
    };

    # Symlinks for tool configs
    lyte.userSymlinks = {
      # Fish functions (autoloaded from ~/.config/fish/functions/)
      ".config/fish/functions/d.fish" = "${flakePath}/dotfiles/fish/functions/d.fish";
      ".config/fish/functions/c.fish" = "${flakePath}/dotfiles/fish/functions/c.fish";
      ".config/fish/functions/ltl.fish" = "${flakePath}/dotfiles/fish/functions/ltl.fish";
      ".config/fish/functions/g.fish" = "${flakePath}/dotfiles/fish/functions/g.fish";
      ".config/fish/functions/lag.fish" = "${flakePath}/dotfiles/fish/functions/lag.fish";
      ".config/fish/functions/jujutsu-git-colocate.fish" =
        "${flakePath}/dotfiles/fish/functions/jujutsu-git-colocate.fish";
      ".config/fish/functions/pp.fish" = "${flakePath}/dotfiles/fish/functions/pp.fish";
      # Fish conf.d
      ".config/fish/conf.d/aliases.fish" = "${flakePath}/dotfiles/fish/conf.d/aliases.fish";

      # Tool configs
      ".config/helix/config.toml" = "${flakePath}/dotfiles/helix/config.toml";
      ".config/helix/languages.toml" = "${flakePath}/dotfiles/helix/languages.toml";
      ".config/helix/themes/custom.toml" = "${flakePath}/dotfiles/helix/themes/custom.toml";
      ".config/lldb_vscode_rustc_primer.py" = "${flakePath}/dotfiles/helix/lldb_vscode_rustc_primer.py";
      ".config/atuin/config.toml" = "${flakePath}/dotfiles/atuin/config.toml";
      ".config/bat/config" = "${flakePath}/dotfiles/bat/config";
      ".config/git/config.local" = "${flakePath}/dotfiles/git/config.local";
      ".config/jj/config.toml" = "${flakePath}/dotfiles/jujutsu/config.toml";
      ".config/zellij/config.kdl" = "${flakePath}/dotfiles/zellij/config.kdl";
      ".config/htop/htoprc" = "${flakePath}/dotfiles/htop/htoprc";
      ".config/senpai/senpai.scfg" = "${flakePath}/dotfiles/senpai/senpai.scfg";
      ".cargo/config.toml" = "${flakePath}/dotfiles/cargo/config.toml";
      ".iex.exs" = "${flakePath}/dotfiles/iex/.iex.exs";
      ".ssh/config" = "${flakePath}/dotfiles/ssh/config";
    };

    # has_command function (used by other fish config)
    # pp function (persistent ping)
  };
}
