{
  lib,
  pkgs,
  config,
  options,
  ...
}:
let
  cfg = config.lyte;
  dotfilesPath = cfg.dotfilesPath;
  danielHome = config.users.users.daniel.home;
  hasNewKanidmModule = options.services.kanidm ? client;
in
{
  options = {
    lyte = {
      shell = {
        enable = lib.mkEnableOption "Enable my default shell configuration and applications";
      };
    };
  };

  config = lib.mkIf cfg.shell.enable {
    services.kanidm =
      if hasNewKanidmModule then { client.enable = true; } else { enableClient = true; };
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

        # Fish shell init (sourced live from dotfiles via flakePath)
        shellInit = "source ${dotfilesPath}/fish/shellInit.fish";
        interactiveShellInit = ''
          source ${dotfilesPath}/fish/interactiveShellInit.fish

          # Shell integrations
          ${pkgs.atuin}/bin/atuin hex init | source
          ${pkgs.atuin}/bin/atuin init fish --disable-up-arrow | source
          ${pkgs.direnv}/bin/direnv hook fish | source
          ${pkgs.fzf}/bin/fzf --fish | source
        '';

        # All aliases live in dotfiles/fish/conf.d/aliases.fish
        # and dotfiles/fish/functions/
        shellAliases = { };
      };

      traceroute.enable = true;

      git = {
        enable = true;
        package = pkgs.gitFull;
        lfs.enable = true;
      };
    };

    environment = {
      # Disable NixOS default "ls = ls --color=tty" — we use eza aliases
      # in dotfiles/fish/conf.d/aliases.fish instead
      shellAliases.ls = null;

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
      ".config/fish/functions/d.fish" = "${dotfilesPath}/fish/functions/d.fish";
      ".config/fish/functions/c.fish" = "${dotfilesPath}/fish/functions/c.fish";
      ".config/fish/functions/ltl.fish" = "${dotfilesPath}/fish/functions/ltl.fish";
      ".config/fish/functions/g.fish" = "${dotfilesPath}/fish/functions/g.fish";
      ".config/fish/functions/lag.fish" = "${dotfilesPath}/fish/functions/lag.fish";
      ".config/fish/functions/jujutsu-git-colocate.fish" =
        "${dotfilesPath}/fish/functions/jujutsu-git-colocate.fish";
      ".config/fish/functions/pp.fish" = "${dotfilesPath}/fish/functions/pp.fish";
      ".config/fish/functions/git.fish" = "${dotfilesPath}/fish/functions/git.fish";
      # Fish conf.d
      ".config/fish/conf.d/aliases.fish" = "${dotfilesPath}/fish/conf.d/aliases.fish";

      # direnv (sources nix-direnv from /run/current-system)
      ".config/direnv/direnvrc" = "${dotfilesPath}/direnv/direnvrc";

      # Tool configs
      ".config/helix/config.toml" = "${dotfilesPath}/helix/config.toml";
      ".config/helix/languages.toml" = "${dotfilesPath}/helix/languages.toml";
      ".config/helix/themes/custom.toml" = "${dotfilesPath}/helix/themes/custom.toml";
      ".config/helix/runtime/queries/hjson/highlights.scm" =
        "${dotfilesPath}/helix/queries/hjson/highlights.scm";
      ".config/lldb_vscode_rustc_primer.py" = "${dotfilesPath}/helix/lldb_vscode_rustc_primer.py";
      ".config/atuin/config.toml" = "${dotfilesPath}/atuin/config.toml";
      ".config/bat/config" = "${dotfilesPath}/bat/config";
      ".config/git/config" = "${dotfilesPath}/git/config.local";
      ".config/jj/config.toml" = "${dotfilesPath}/jujutsu/config.toml";
      ".config/zellij/config.kdl" = "${dotfilesPath}/zellij/config.kdl";
      ".config/zellij/layouts/compact-keys.kdl" = "${dotfilesPath}/zellij/layouts/compact-keys.kdl";
      ".config/htop/htoprc" = "${dotfilesPath}/htop/htoprc";
      ".config/senpai/senpai.scfg" = "${dotfilesPath}/senpai/senpai.scfg";
      ".cargo/config.toml" = "${dotfilesPath}/cargo/config.toml";
      ".iex.exs" = "${dotfilesPath}/iex/.iex.exs";
      ".ssh/config" = "${dotfilesPath}/ssh/config";
    };

    # has_command function (used by other fish config)
    # pp function (persistent ping)
  };
}
