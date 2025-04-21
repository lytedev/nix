{
  networking = {
    # TODO: why was I working on nixos-containers? ad-hoc "baby nix modules/vms"?
    nat = {
      # for NAT'ing to nixos-containers
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eno1";
    };
    # bridges.br0.interfaces = [ "eno1" ]; # Adjust interface accordingly

    # Get bridge-ip with DHCP
    # useDHCP = false;
    # interfaces."br0".useDHCP = true;

    # Set bridge-ip static
    # interfaces."br0".ipv4.addresses = [{
    #   address = "10.233.2.0";
    #   prefixLength = 24;
    # }];
    # defaultGateway = "192.168.100.1";
    # nameservers = [ "192.168.100.1" ];

    networkmanager.unmanaged = [ "interface-name:ve-*" ];
    hostName = "beefcake";
    hostId = "541ede55";
  };
  services.tailscale.useRoutingFeatures = "server";
}
