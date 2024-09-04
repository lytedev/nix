{
  lib,
  # outputs,
  # config,
  pkgs,
  ...
}: let
  # NOTE: My goal is to be able to apply most of the common tweaks to the router
  # either live on the system for ad-hoc changes (such as forwarding a port for a
  # multiplayer game) or to tweak these values just below without reaching deeper
  # into the modules' implementation of these configuration values
  # NOTE: I could turn this into a cool NixOS module?
  # TODO: review https://francis.begyn.be/blog/nixos-home-router
  # TODO: more recent: https://github.com/ghostbuster91/blogposts/blob/a2374f0039f8cdf4faddeaaa0347661ffc2ec7cf/router2023-part2/main.md
  hostname = "router";
  domain = "h.lyte.dev";
  ip = "192.168.0.1";
  cidr = "${ip}/16";
  netmask = "255.255.255.0"; # see cidr
  dhcp_lease_space = {
    min = "192.168.0.30";
    max = "192.168.0.250";
  };
  interfaces = {
    wan = {
      name = "wan";
      mac = "00:01:2e:82:73:59";
    };
    lan = {
      name = "lan";
      mac = "00:01:2e:82:73:5a";
    };
  };
  hosts = {
    dragon = {
      ip = "192.168.0.10";
    };
    bald = {
      ip = "192.168.0.11";
      additionalHosts = [
        "ourcraft.lyte.dev"
      ];
    };
    beefcake = {
      ip = "192.168.0.9";
      additionalHosts = [
        ".beefcake.lan"
        "nix.h.lyte.dev"
        "idm.h.lyte.dev"
        "git.lyte.dev"
        "video.lyte.dev"
        "audio.lyte.dev"
        "a.lyte.dev"
        "bw.lyte.dev"
        "files.lyte.dev"
        "vpn.h.lyte.dev"
        "atuin.h.lyte.dev"
        "a.lyte.dev"
      ];
    };
  };
  sysctl-entries = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.${interfaces.wan.name}.rp_filter" = 1;
    "net.ipv4.conf.${interfaces.lan.name}.rp_filter" = 0;

    "net.ipv6.conf.${interfaces.wan.name}.accept_ra" = 2;
    "net.ipv6.conf.${interfaces.wan.name}.autoconf" = 1;

    "net.ipv6.conf.all.use_tempaddr" = 2;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 2;
    "net.ipv6.conf.${interfaces.wan.name}.use_tempaddr" = 2;
    # "net.ipv6.conf.${interfaces.wan.name}.addr_gen_mode" = 2;
  };
in {
  imports = [
    {
      # hardware
      boot = {
        loader = {
          efi.canTouchEfiVariables = true;
          systemd-boot.enable = true;
        };
        initrd.availableKernelModules = ["xhci_pci"];
        initrd.kernelModules = [];
        kernelModules = ["kvm-intel"];
        extraModulePackages = [];
      };

      nixpkgs.hostPlatform = "x86_64-linux";
      powerManagement.cpuFreqGovernor = "performance";
      hardware.cpu.intel.updateMicrocode = true;
    }
  ];

  boot.kernel.sysctl =
    sysctl-entries
    // {
    };

  networking = {
    hostName = hostname;
    domain = domain;

    # disable some of the sane defaults
    useDHCP = false;
    firewall.enable = false;

    # use systemd.network for network interface configuration
    useNetworkd = true;

    # maybe we need this?
    nat.enable = true;

    extraHosts = ''
      127.0.0.1 localhost
      127.0.0.2 ${hostname}.${domain} ${hostname}
      ${ip} ${hostname}.${domain} ${hostname}

      ::1 localhost ip6-localhost ip6-loopback
      ff02::1 ip6-allnodes
      ff02::2 ip6-allrouters
    '';

    # the main meat and potatoes for most routers, the firewall configuration
    # TODO: IPv6
    nftables = let
      inf = {
        lan = interfaces.lan.name;
        wan = interfaces.wan.name;
      };
    in {
      enable = true;
      checkRuleset = true;
      ruleset = with inf; ''
        table inet filter {
        	# set LANv4 {
        	# 	type ipv4_addr
        	# 	flags interval
        	# 	elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
        	# }
        	# set LANv6 {
        	# 	type ipv6_addr
        	# 	flags interval
        	# 	elements = { fd00::/8, fe80::/10 }
        	# }
          # TODO: maybe tailnet?

        	# chain my_input_lan {
        	# 	udp sport 1900 udp dport >= 1024 meta pkttype unicast limit rate 4/second burst 20 packets accept comment "Accept UPnP IGD port mapping reply"
        	# 	udp sport netbios-ns udp dport >= 1024 meta pkttype unicast accept comment "Accept Samba Workgroup browsing replies"
        	# }

          chain input {
            type filter hook input priority 0; policy drop;

        		iif lo accept comment "Accept any localhost traffic"
        		ct state invalid drop comment "Drop invalid connections"
        		ct state established,related accept comment "Accept traffic originated from us"

        		meta l4proto ipv6-icmp accept comment "Accept ICMPv6"
        		meta l4proto icmp accept comment "Accept ICMP"
        		ip protocol igmp accept comment "Accept IGMP"

            ip6 nexthdr icmpv6 icmpv6 type nd-router-solicit accept
            ip6 nexthdr icmpv6 icmpv6 type nd-router-advert  accept comment "Accept IPv6 router advertisements"
            udp dport dhcpv6-client accept comment "IPv6 DHCP"

            ip6 nexthdr icmpv6 icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert, mld-listener-query, destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept comment "Accept IPv6 ICMP and meta stuff"
            ip protocol icmp icmp type { echo-request, destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept comment "Accept IPv4 ICMP and meta stuff"
            ip protocol icmpv6 accept
            ip protocol icmp accept
            meta l4proto ipv6-icmp counter accept
            udp dport dhcpv6-client counter accept

        		udp dport mdns ip6 daddr ff02::fb accept comment "Accept mDNS"
        		udp dport mdns ip daddr 224.0.0.251 accept comment "Accept mDNS"

        		tcp dport 2201 accept comment "Accept SSH on port 2201"
        		tcp dport 53 accept comment "Accept DNS"
        		udp dport 53 accept comment "Accept DNS"

            tcp dport { 80, 443 } accept comment "Allow HTTP/HTTPS to server (see nat prerouting)"
            udp dport { 80, 443 } accept comment "Allow QUIC to server (see nat prerouting)"
            tcp dport { 22 } accept comment "Allow SSH to server (see nat prerouting)"
            tcp dport { 25565 } accept comment "Allow Minecraft server connections (see nat prerouting)"

            iifname "${lan}" accept comment "Allow local network to access the router"
            iifname "tailscale0" accept comment "Allow local network to access the router"

        		# ip6 saddr @LANv6 jump my_input_lan comment "Connections from private IP address ranges"
        		# ip saddr @LANv4 jump my_input_lan comment "Connections from private IP address ranges"

            iifname "${wan}" counter drop comment "Drop all other unsolicited traffic from wan"
          }

          chain output {
            type filter hook output priority 0;
            accept
          }

          chain forward {
            type filter hook forward priority 0;
            accept
          }

          # chain forward {
          #   type filter hook forward priority filter; policy drop;

          #   iifname { "${lan}" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
          #   iifname { "tailscale0" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
          #   iifname { "${wan}" } oifname { "${lan}" } ct state { established, related } accept comment "Allow established back to LAN"
          # }
        }

        table ip nat {
          chain prerouting {
            type nat hook prerouting priority dstnat;

          	iifname ${lan} accept
          	iifname tailscale0 accept

            iifname ${wan} tcp dport {22} dnat to ${hosts.beefcake.ip}
            iifname ${wan} tcp dport {80, 443} dnat to ${hosts.beefcake.ip}
            iifname ${wan} udp dport {80, 443} dnat to ${hosts.beefcake.ip}
            iifname ${wan} tcp dport {26966} dnat to ${hosts.beefcake.ip}
            iifname ${wan} tcp dport {25565} dnat to ${hosts.bald.ip}
            iifname ${wan} udp dport {25565} dnat to ${hosts.bald.ip}
          }

          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "${wan}" masquerade
          }
        }
      '';
    };

    # NOTE: see flake.nix 'nnf.nixosModules.default'
    # nftables.firewall = let
    #   me = config.networking.nftables.firewall.localZoneName;
    # in {
    #   enable = true;
    #   snippets.nnf-common.enable = true;

    #   zones = {
    #     ${interfaces.wan.name} = {
    #       interfaces = [interfaces.wan.name interfaces.lan.name];
    #     };
    #     ${interfaces.lan.name} = {
    #       parent = interfaces.wan.name;
    #       ipv4Addresses = [cidr];
    #     };
    #     # banned = {
    #     #   ingressExpression = [
    #     #     "ip saddr @banlist"
    #     #     "ip6 saddr @banlist6"
    #     #   ];
    #     #   egressExpression = [
    #     #     "ip daddr @banlist"
    #     #     "ip6 daddr @banlist6"
    #     #   ];
    #     # };
    #   };

    #   rules = {
    #     dhcp = {
    #       from = "all";
    #       to = [hosts.beefcake.ip];
    #       allowedTCPPorts = [67];
    #       allowedUDPPorts = [67];
    #     };
    #     http = {
    #       from = "all";
    #       to = [me];
    #       allowedTCPPorts = [80 443];
    #     };
    #     router-ssh = {
    #       from = "all";
    #       to = [me];
    #       allowedTCPPorts = [2201];
    #     };
    #     server-ssh = {
    #       from = "all";
    #       to = [hosts.beefcake.ip];
    #       allowedTCPPorts = [22];
    #     };
    #   };
    # };
  };

  systemd.network = {
    enable = true;
    # wait-online.anyInterface = true;

    # configure known names for the network interfaces
    links = {
      "20-${interfaces.wan.name}" = {
        enable = true;
        matchConfig = {
          MACAddress = interfaces.wan.mac;
        };
        linkConfig = {
          Name = interfaces.wan.name;
        };
      };
      "30-${interfaces.lan.name}" = {
        enable = true;
        matchConfig = {
          MACAddress = interfaces.lan.mac;
        };
        linkConfig = {
          Name = interfaces.lan.name;
        };
      };
    };

    # configure networks for the interfaces
    networks = {
      # LAN configuration is very simple and mostly forwarded between
      # TODO: IPv6
      "50-${interfaces.lan.name}" = {
        matchConfig.Name = "${interfaces.lan.name}";
        linkConfig = {
          RequiredForOnline = "enslaved";
          # Name = interfaces.lan.name;
        };

        address = [
          cidr
        ];
        networkConfig = {
          # Description = "LAN network - connection to switch in house";
          ConfigureWithoutCarrier = true;
          # IPv6AcceptRA = false;
          IPv6SendRA = true;
          DHCPv6PrefixDelegation = true;
        };
      };

      # WAN configuration requires DHCP to get addresses
      # we also disable some options to be certain we retain as much networking
      # control as we reasonably can, such as not letting the ISP determine our
      # hostname or DNS configuration
      # TODO: IPv6 (prefix delegation)
      "40-${interfaces.wan.name}" = {
        matchConfig.Name = "${interfaces.wan.name}";
        networkConfig = {
          Description = "WAN network - connection to fiber ISP jack";
          DHCP = true;
          # IPv6AcceptRA = true;
          # IPv6PrivacyExtensions = true;
          # IPForward = true;
        };
        dhcpV6Config = {
          # ForceDHCPv6PDOtherInformation = true;
          # UseHostname = false;
          # UseDNS = false;
          # UseNTP = false;
          PrefixDelegationHint = "::/56";
        };
        dhcpV4Config = {
          Hostname = hostname;
          UseHostname = false;
          UseDNS = false;
          UseNTP = false;
          UseSIP = false;
          UseRoutes = false;
          UseGateway = true;
        };
        linkConfig = {
          RequiredForOnline = "routable";
          # Name = interfaces.wan.name;
        };
        ipv6AcceptRAConfig = {
          DHCPv6Client = "always";
          UseDNS = false;
        };
      };
    };
  };

  services.resolved.enable = false;

  # dnsmasq serves as our DHCP and DNS server
  # almost all the configuration should be derived from the values at the top of
  # this file
  services.dnsmasq = {
    enable = true;
    settings = {
      listen-address = "::,127.0.0.1,${ip}";
      port = 53;

      # dhcp-authoritative = true;
      # dnssec = true;
      enable-ra = true;

      server = ["1.1.1.1" "9.9.9.9" "8.8.8.8"];

      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;

      cache-size = "10000";

      dhcp-range = with dhcp_lease_space; [
        "${interfaces.lan.name},${min},${max},${netmask},24h"
        "::,constructor:${interfaces.lan.name},ra-stateless,ra-names,4h"
      ];
      except-interface = interfaces.wan.name;
      interface = interfaces.lan.name;
      dhcp-host =
        [
        ]
        ++ (lib.attrsets.mapAttrsToList (name: {
          ip,
          identifier ? name,
          time ? "12h",
          ...
        }: "${name},${ip},${identifier},${time}")
        hosts);

      address =
        [
          "/${hostname}.${domain}/${ip}"
        ]
        ++ (lib.lists.flatten (lib.attrsets.mapAttrsToList (name: {
            ip,
            additionalHosts ? [],
            identifier ? name,
            time ? "12h",
          }: [
            "/${name}.${domain}/${ip}"
            (lib.lists.forEach additionalHosts (h: "/${h}/${ip}"))
          ])
          hosts));

      # local domains
      local = "/lan/";
      domain = "lan";
      expand-hosts = true;

      # don't use /etc/hosts as this would advertise surfer as localhost
      no-hosts = true;
    };
  };

  # since the home network reserves port 22 for ssh to the big server and to
  # gitea, the router uses port 2201 for ssh
  services.openssh.listenAddresses = [
    {
      addr = "0.0.0.0";
      port = 2201;
    }
    {
      addr = "0.0.0.0";
      port = 22;
    }
    {
      addr = "[::]";
      port = 2201;
    }
    {
      addr = "[::]";
      port = 22;
    }
  ];

  services.fail2ban.enable = true;

  system.stateVersion = "24.05";

  # NOTE: everything from here on is deprecated or old stuff

  # TODO: may not be strictly necessary for IPv6?
  # TODO: also may not even be the best implementation?
  # services.radvd = {
  #   enable = false;
  #   # NOTE: this config is just the default arch linux config I think and may
  #   # need tweaking? this is what I had on the arch linux router, though :shrug:
  #   config = ''
  #     interface lo
  #     {
  #     	AdvSendAdvert on;
  #     	MinRtrAdvInterval 3;
  #     	MaxRtrAdvInterval 10;
  #     	AdvDefaultPreference low;
  #     	AdvHomeAgentFlag off;

  #     	prefix 2001:db8:1:0::/64
  #     	{
  #     		AdvOnLink on;
  #     		AdvAutonomous on;
  #     		AdvRouterAddr off;
  #     	};

  #     	prefix 0:0:0:1234::/64
  #     	{
  #     		AdvOnLink on;
  #     		AdvAutonomous on;
  #     		AdvRouterAddr off;
  #     		Base6to4Interface ppp0;
  #     		AdvPreferredLifetime 120;
  #     		AdvValidLifetime 300;
  #     	};

  #     	route 2001:db0:fff::/48
  #     	{
  #     		AdvRoutePreference high;
  #     		AdvRouteLifetime 3600;
  #     	};

  #       RDNSS 2001:db8::1 2001:db8::2
  #       {
  #         AdvRDNSSLifetime 30;
  #       };

  #       DNSSL branch.example.com example.com
  #       {
  #         AdvDNSSLLifetime 30;
  #       };
  #     };
  #   '';
  # };

  # TODO: old config, should be deleted ASAP
  # services.dnsmasq = {
  #   enable = false;
  #   settings = {
  #     # server endpoints
  #     listen-address = "::1,127.0.0.1,${ip}";
  #     port = "53";

  #     # DNS cache entries
  #     cache-size = "10000";

  #     # local domain entries
  #     local = "/lan/";
  #     domain = "lan";
  #     expand-hosts = true;

  #     dhcp-authoritative = true;

  #     conf-file = "/usr/share/dnsmasq/trust-anchors.conf";
  #     dnssec = true;

  #     except-interface = "${wan_if}";
  #     interface = "${lan_if}";

  #     enable-ra = true;

  #     # dhcp-option = "121,${cidr},${ip}";

  #     dhcp-range = [
  #       "lan,${dhcp_lease_space.min},${dhcp_lease_space.max},${netmask},10m"
  #       "tag:${lan_if},::1,constructor:${lan_if},ra-names,12h"
  #     ];

  #     dhcp-host = [
  #       "${hosts.dragon.host},${hosts.dragon.ip},12h"
  #       "${hosts.beefcake.host},${hosts.beefcake.ip},12h"
  #     ];

  #     # may need to go in /etc/hosts (networking.extraHosts), too?
  #     address = [
  #       "/video.lyte.dev/192.168.0.9"
  #       "/git.lyte.dev/192.168.0.9"
  #       "/bw.lyte.dev/192.168.0.9"
  #       "/files.lyte.dev/192.168.0.9"
  #       "/vpn.h.lyte.dev/192.168.0.9"
  #       "/.h.lyte.dev/192.168.0.9"
  #     ];

  #     server = [
  #       "${ip}"
  #       "8.8.8.8"
  #       "8.8.4.4"
  #       "1.1.1.1"
  #       "1.0.0.1"
  #     ];
  #   };
  # };

  # TODO: old config, should be deleted ASAP
  # nftables = {
  #   enable = false;
  #   flushRuleset = true;

  #   tables = {
  #     filter = {
  #       family = "inet";
  #       content = ''
  #         chain input {
  #           # type filter hook input priority filter; policy accept;
  #           type filter hook input priority 0;

  #           # anything from loopback interface
  #           iifname "lo" accept

  #           # accept traffic we originated
  #           ct state { established, related } counter accept
  #           ct state invalid counter drop

  #           # ICMP
  #           ip6 nexthdr icmpv6 icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert, mld-listener-query, destination-unreachable, packet-too-big, time-exceeded, parameter-problem } counter accept
  #           ip protocol icmp icmp type { echo-request, destination-unreachable, router-advertisement, time-exceeded, parameter-problem } counter accept
  #           ip protocol icmpv6 counter accept
  #           ip protocol icmp counter accept
  #           meta l4proto ipv6-icmp counter accept
  #           udp dport dhcpv6-client counter accept

  #           tcp dport { 64022, 22, 53, 67, 25565 } counter accept
  #           udp dport { 64020, 22, 53, 67 } counter accept

  #           # iifname "iot" ip saddr $iot-ip tcp dport { llmnr } counter accept
  #           # iifname "iot" ip saddr $iot-ip udp dport { mdns, llmnr } counter accept
  #           iifname "${lan_if}" tcp dport { llmnr } counter accept
  #           iifname "${lan_if}" udp dport { mdns, llmnr } counter accept

  #           counter drop
  #         }

  #         # allow all outgoing
  #         chain output {
  #           type filter hook output priority 0;
  #           accept
  #         }

  #         chain forward {
  #           type filter hook forward priority 0;
  #           accept
  #         }
  #       '';
  #     };

  #     nat = {
  #       family = "ip";
  #       content = ''
  #         set masq_saddr {
  #         	type ipv4_addr
  #         	flags interval
  #         	elements = { ${cidr} }
  #         }

  #         map map_port_ipport {
  #         	type inet_proto . inet_service : ipv4_addr . inet_service
  #         }

  #         chain prerouting {
  #         	iifname ${lan_if} accept

  #         	type nat hook prerouting priority dstnat + 1; policy accept;
  #         	fib daddr type local dnat ip addr . port to meta l4proto . th dport map @map_port_ipport

  #         	iifname ${wan_if} tcp dport { 22, 80, 443, 25565, 64022 } dnat to ${hosts.beefcake.ip}
  #         	iifname ${wan_if} udp dport { 64020 } dnat to ${hosts.beefcake.ip}

  #         	# iifname ${wan_if} tcp dport { 25565 } dnat to 192.168.0.244
  #         	# iifname ${wan_if} udp dport { 25565 } dnat to 192.168.0.244

  #         	# router
  #         	iifname ${wan_if} tcp dport { 2201 } dnat to ${ip}
  #         }

  #         chain output {
  #         	type nat hook output priority -99; policy accept;
  #         	ip daddr != 127.0.0.0/8 oif "lo" dnat ip addr . port to meta l4proto . th dport map @map_port_ipport
  #         }

  #         chain postrouting {
  #         	type nat hook postrouting priority srcnat + 1; policy accept;
  #         	oifname ${lan_if} masquerade
  #         	ip saddr @masq_saddr masquerade
  #         }
  #       '';
  #     };
  #   };
  # };

  # TODO: also want to try to avoid using dhcpcd for IPv6 since systemd-networkd
  # should be sufficient?
  # dhcpcd = {
  #   enable = false;
  #   extraConfig = ''
  #     duid

  #     # No way.... https://github.com/NetworkConfiguration/dhcpcd/issues/36#issuecomment-954777644
  #     # issues caused by guests with oneplus devices
  #     noarp

  #     persistent
  #     vendorclassid

  #     option domain_name_servers, domain_name, domain_search
  #     option classless_static_routes
  #     option interface_mtu
  #     option host_name
  #     #option ntp_servers

  #     require dhcp_server_identifier
  #     slaac private
  #     noipv4ll
  #     noipv6rs

  #     static domain_name_servers=${ip}

  #     interface ${wan_if}
  #     	gateway
  #     	ipv6rs
  #     	iaid 1
  #     	# option rapid_commit
  #     	# ia_na 1
  #     	ia_pd 1 ${lan_if}

  #     interface ${lan_if}
  #     	static ip_address=${cidr}
  #     	static routers=${ip}
  #     	static domain_name_servers=${ip}
  #   '';
  # };
}
