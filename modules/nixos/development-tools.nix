{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    watchexec
    android-tools
    libresprite
    audacity
    wol
    shellcheck
    shfmt
    bash-language-server
    xh
    jq
    curl
  ];
}
