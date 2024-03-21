{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    watchexec
    android-tools
    kubectl
    stern
    libresprite
    logseq
    audacity
    wol
    shellcheck
    shfmt
    nodePackages.bash-language-server
    nodePackages.yaml-language-server
    xh
    jq
    curl
  ];
}
