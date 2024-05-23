{pkgs, ...}: {
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  programs.neovim = {
    enable = true;
    # plugins = [
    #   pkgs.vimPlugins.nvim-treesitter.withAllGrammars
    # ];
  };

  environment.systemPackages = with pkgs; [
    taplo # toml language server for editing helix configs per repo
    pgcli
    oil
    watchexec
    android-tools
    kubectl
    stern
    libresprite
    logseq
    audacity
    wol
    shellcheck
    skim
    gron
    shfmt
    vscode-langservers-extracted
    nodePackages.bash-language-server
    nodePackages.yaml-language-server
    xh
    curl
    google-chrome
  ];

  services.udev.packages = [
    pkgs.platformio
    pkgs.openocd
  ];

  programs.adb.enable = true;
  users.users.daniel.extraGroups = ["adbusers"];

  home-manager.users.daniel = {
    home = {
    };

    programs.nushell = {
      enable = true;
    };

    programs.jujutsu = {
      enable = true;
    };

    programs.k9s = {
      enable = true;
    };

    programs.vscode = {
      enable = true;
    };

    programs.jq = {
      enable = true;
    };

    programs.chromium = {
      enable = true;
    };
  };
}
