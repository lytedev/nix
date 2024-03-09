{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    nmap
  ];
}
