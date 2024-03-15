{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    taplo # toml language server for editing helix configs per repo
    watchexec
    android-tools
    kubectl
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
