{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    htop
    bottom
    nmap
    dogdns
    dnsutils
  ];
}
