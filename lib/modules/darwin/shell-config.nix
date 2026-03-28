{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.lyte;
  dotfilesPath = cfg.dotfilesPath;
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
    programs = {
      fish = {
        enable = true;

        shellInit = "source ${dotfilesPath}/fish/shellInit.fish";
        interactiveShellInit = ''
          source ${dotfilesPath}/fish/interactiveShellInit.fish

          # Shell integrations
          ${pkgs.atuin}/bin/atuin hex init | source
          ${pkgs.atuin}/bin/atuin init fish --disable-up-arrow | source
          ${pkgs.direnv}/bin/direnv hook fish | source
          ${pkgs.fzf}/bin/fzf --fish | source
        '';

        shellAliases = { };
      };
    };

    environment = {
      # NixOS allows null to unset aliases, but nix-darwin does not
      # shellAliases.ls = null;

      variables = {
        EDITOR = "hx";
        VISUAL = "hx";
        PAGER = "bat --style=plain";
        MANPAGER = "bat --style=plain";
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
        dua
        eza
        fd
        file
        gawk
        helix
        hexyl
        htop
        jq
        jujutsu
        nil
        nixd
        nixfmt-rfc-style
        ripgrep
        rsync
        sd
        w3m
        xh
        zellij

        # Custom scripts (common only — no linux scripts on darwin)
        (pkgs.buildEnv {
          name = "my-common-scripts";
          paths = [ ../home/scripts/common ];
        })
      ];
    };

    # Symlinks for tool configs
    lyte.userSymlinks = {
      # Fish functions
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

      # direnv
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
      ".cargo/config.toml" = "${dotfilesPath}/cargo/config.toml";
      ".iex.exs" = "${dotfilesPath}/iex/.iex.exs";
      ".ssh/config" = "${dotfilesPath}/ssh/config";
    };
  };
}
