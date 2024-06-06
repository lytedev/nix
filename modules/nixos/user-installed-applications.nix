{pkgs, ...}: {
  services.flatpak.enable = true;
  programs.appimage.binfmt = true;
}
