{
  flake,
  inputs,
  lib,
  # outputs,
  # config,
  pkgs,
  ...
}: let
  ip = "192.168.0.1";
  cidr = "${ip}/16";
  netmask = "255.255.0.0";
  lease = {
    min = "192.168.0.5";
    max = "192.168.0.250";
  };
  wan_if = "wan0";
  lan_if = "lan0";
  hosts = {
    dragon = {
      identifier = "dragon";
      host = "dragon";
      ip = "192.168.0.10";
    };
  };
in {
  networking.hostName = "router";
  networking.domain = "h.lyte.dev";

  imports = [
    inputs.disko.nixosModules.disko
    flake.diskoConfigurations.unencrypted
  ];

  # TODO: perform a hardware scan

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernel = {
      sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
        "net.ipv6.conf.wan0.accept_ra" = 2;
      };
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.fail2ban.enable = true;
  services.radvd = {
    enable = true;
    # TODO: this config is just the default arch linux config I think and may
    # need tweaking? this is what I had on the arch linux router, though :shrug:
    config = ''
      interface lo
      {
      	AdvSendAdvert on;
      	MinRtrAdvInterval 3;
      	MaxRtrAdvInterval 10;
      	AdvDefaultPreference low;
      	AdvHomeAgentFlag off;

      	prefix 2001:db8:1:0::/64
      	{
      		AdvOnLink on;
      		AdvAutonomous on;
      		AdvRouterAddr off;
      	};

      	prefix 0:0:0:1234::/64
      	{
      		AdvOnLink on;
      		AdvAutonomous on;
      		AdvRouterAddr off;
      		Base6to4Interface ppp0;
      		AdvPreferredLifetime 120;
      		AdvValidLifetime 300;
      	};

      	route 2001:db0:fff::/48
      	{
      		AdvRoutePreference high;
      		AdvRouteLifetime 3600;
      	};

        RDNSS 2001:db8::1 2001:db8::2
        {
          AdvRDNSSLifetime 30;
        };

        DNSSL branch.example.com example.com
        {
          AdvDNSSLLifetime 30;
        };
      };
    '';
  };

  # TODO: lan0 and wan0 systemd.network.link ?

  networking.extraHosts = ''
    127.0.0.1 localhost
    127.0.1.1 router.h.lyte.dev router

    ::1 localhost ip6-localhost ip6-loopback
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters

    192.168.0.9 git.lyte.dev
    192.168.0.9 video.lyte.dev
    192.168.0.9 files.lyte.dev
    192.168.0.9 bw.lyte.dev
    192.168.0.9 vpn.h.lyte.dev
  '';

  services.resolved = {
    enable = true;
    extraConfig = ''
      [Resolve]
      DNSStubListener=no
    '';
  };

  networking.firewall = {
    # TODO: port router firewall config
    enable = true;
    package = pkgs.nftables;
    allowPing = true;
    allowedTCPPorts = [22];
    allowedUDPPorts = [];
  };

  networking.dhcpcd = {
    enable = true;
    extraConfig = ''
      duid

      # No way.... https://github.com/NetworkConfiguration/dhcpcd/issues/36#issuecomment-954777644
      # issues caused by guests with oneplus devices
      noarp
      persistent
      vendorclassid

      option domain_name_servers, domain_name, domain_search
      option classless_static_routes
      option interface_mtu
      option host_name
      #option ntp_servers

      require dhcp_server_identifier
      slaac private
      noipv4ll
      noipv6rs

      static domain_name_servers=${ip}

      interface ${wan_if}
      	gateway
      	ipv6rs
      	iaid 1
      	# option rapid_commit
      	# ia_na 1
      	ia_pd 1 ${lan_if}

      interface ${lan_if}
      	static ip_address=${cidr}
      	static routers=${ip}
      	static domain_name_servers=${ip}
    '';
  };

  services.dnsmasq = {
    enable = true;
    # TODO: port to settings
    extraConfig = ''
      # server endpoints
      listen-address=::1,127.0.0.1,${ip}
      port=53

      # DNS cache entries
      cache-size=10000

      # local domain entries
      local=/lan/
      domain=lan
      expand-hosts

      dhcp-authoritative

      conf-file=/usr/share/dnsmasq/trust-anchors.conf
      dnssec

      except-interface=${wan_if}
      interface=${lan_if}

      enable-ra

      # dhcp-option=121,${cidr},${ip}

      dhcp-range=lan,${lease.min},${lease.max},${netmask},10m
      dhcp-range=tag:${lan_if},::1,constructor:${lan_if},ra-names,12h

      dhcp-host=${hosts.dragon.identifier},${hosts.dragon.ip},12h

      # TODO: parameterize the rest?

      dhcp-host=beefcake,192.168.0.9,12h
      dhcp-host=chromebox,192.168.0.5,12h
      dhcp-host=B-C02G56VXML85,192.168.0.128,12h
      dhcp-host=B-W4KNHWJ6XY,192.168.0.217,12h
      dhcp-host=mnemonic,192.168.0.248,ea:1b:7a:fb:8b:b8,12h
      # dhcp-host=frontdoorcam,192.168.0.89,9c:8e:cd:2b:71:e9,120m
      dhcp-host=AMC058BA_A75F1E,192.168.0.150,12h
      dhcp-host=AMC0587F_A2969A,192.168.0.151,12h

      address=/video.lyte.dev/192.168.0.9
      address=/git.lyte.dev/192.168.0.9
      address=/bw.lyte.dev/192.168.0.9
      address=/files.lyte.dev/192.168.0.9
      address=/vpn.h.lyte.dev/192.168.0.9
      address=/.h.lyte.dev/192.168.0.9

      server=${ip}
      server=8.8.8.8
      server=8.8.4.4
      server=1.1.1.1
      server=1.0.0.1
    '';
  };

  system.stateVersion = "23.11";
}
