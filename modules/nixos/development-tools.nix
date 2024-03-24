{pkgs, ...}: {
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  programs.neovim = {
    enable = true;
    # plugins = [
    #   pkgs.vimPlugins.nvim-treesitter.withAllGrammars
    # ];
  };

  environment.systemPackages = with pkgs; [
    # (gitui.overrideAttrs {
    #   version = "5b3e2c9ae3913855f5dbe463c5ae1c04430e7532";

    #   src = fetchFromGitHub {
    #     owner = "extrawurst";
    #     repo = "gitui";
    #     rev = "5b3e2c9ae3913855f5dbe463c5ae1c04430e7532";
    #     hash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
    #   };

    #   cargoHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    # })
    taplo # toml language server for editing helix configs per repo
    oil
    nushell
    watchexec
    android-tools
    kubectl
    vscode
    stern
    libresprite
    logseq
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
