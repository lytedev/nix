{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    # ls-all-the-things
  ];
}
