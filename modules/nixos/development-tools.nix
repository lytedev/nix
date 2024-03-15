{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    taplo # toml language server for editing helix configs per repo
    watchexec
    android-tools
    libresprite
    audacity
    wol
    shellcheck
    shfmt
    vscode-langservers-extracted
    nodePackages.bash-language-server
    xh
    jq
    curl
  ];
}
