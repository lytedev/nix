{
  # enable mDNS and discovery
  services.avahi = {
    enable = true;
    reflector = true;
    openFirewall = true;
    nssmdns = true;
  };
}
