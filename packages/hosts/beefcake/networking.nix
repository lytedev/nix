{
  networking = {
    # TODO: why was I working on nixos-containers? ad-hoc "baby nix modules/vms"?
    nat = {
      # for NAT'ing to nixos-containers + tailscale exit-node traffic
      # (the tailscale daemon is configured with NetfilterMode=0 so it
      # doesn't install its own masquerade rule; without tailscale0 in
      # internalInterfaces, exit-node clients' packets egress eno1 with
      # their tailnet source IP and replies have no return path)
      enable = true;
      internalInterfaces = [
        "ve-+"
        "tailscale0"
      ];
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
  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-exit-node"
      "--accept-routes"
    ];
  };
}
