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
    watchexec
    android-tools
    kubectl
    vscode
    stern
    libresprite
    audacity
    wol
    shellcheck
    shfmt
    vscode-langservers-extracted
    nodePackages.bash-language-server
    nodePackages.yaml-language-server
    xh
    jq
    curl
  ];
}
