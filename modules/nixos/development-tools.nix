{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    watchexec
    xh
    curl
  ];
}
