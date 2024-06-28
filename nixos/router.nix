{
  lib,
  # outputs,
  # config,
  # pkgs,
  ...
}: let
  # NOTE: I could turn this into a cool NixOS module?
  # TODO: review https://francis.begyn.be/blog/nixos-home-router
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
    beefcake = {
      identifier = "beefcake";
      host = "beefcake";
      ip = "192.168.0.9";
    };
  };
in {
  networking.hostName = "router";
  networking.domain = "h.lyte.dev";
  networking.useDHCP = false;

  # TODO: perform a hardware scan

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernel = {
      sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true;

        "net.ipv6.conf.all.accept_ra" = 0;
        "net.ipv6.conf.all.autoconf" = 0;
        "net.ipv6.conf.all.use_tempaddr" = 0;

        "net.ipv6.conf.wan0.accept_ra" = 2;
        # "net.ipv6.conf.wan0.autoconf" = 1;
      };
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.fail2ban.enable = true;
  services.radvd = {
    enable = true;
    # NOTE: this config is just the default arch linux config I think and may
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

  services.resolved = {
    enable = true;
    extraConfig = ''
      [Resolve]
      DNSStubListener=no
    '';
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      # server endpoints
      listen-address = "::1,127.0.0.1,${ip}";
      port = "53";

      # DNS cache entries
      cache-size = "10000";

      # local domain entries
      local = "/lan/";
      domain = "lan";
      expand-hosts = true;

      dhcp-authoritative = true;

      conf-file = "/usr/share/dnsmasq/trust-anchors.conf";
      dnssec = true;

      except-interface = "${wan_if}";
      interface = "${lan_if}";

      enable-ra = true;

      # dhcp-option = "121,${cidr},${ip}";

      dhcp-range = [
        "lan,${lease.min},${lease.max},${netmask},10m"
        "tag:${lan_if},::1,constructor:${lan_if},ra-names,12h"
      ];

      dhcp-host = [
        "${hosts.dragon.host},${hosts.dragon.ip},12h"
        "${hosts.beefcake.host},${hosts.beefcake.ip},12h"
      ];

      # may need to go in /etc/hosts (networking.extraHosts), too?
      address = [
        "/video.lyte.dev/192.168.0.9"
        "/git.lyte.dev/192.168.0.9"
        "/bw.lyte.dev/192.168.0.9"
        "/files.lyte.dev/192.168.0.9"
        "/vpn.h.lyte.dev/192.168.0.9"
        "/.h.lyte.dev/192.168.0.9"
      ];

      server = [
        "${ip}"
        "8.8.8.8"
        "8.8.4.4"
        "1.1.1.1"
        "1.0.0.1"
      ];
    };
  };

  networking.extraHosts = ''
    127.0.0.1 localhost
    ${ip} router.h.lyte.dev router

    ::1 localhost ip6-localhost ip6-loopback
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters

  '';

  networking.nat.enable = true; # TODO: maybe replace some of the nftables stuff with this?
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    flushRuleset = true;

    tables = {
      filter = {
        family = "inet";
        content = ''
          chain input {
            # type filter hook input priority filter; policy accept;
            type filter hook input priority 0;

            # anything from loopback interface
            iifname "lo" accept

            # accept traffic we originated
            ct state { established, related } counter accept
            ct state invalid counter drop

            # ICMP
            ip6 nexthdr icmpv6 icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert, mld-listener-query, destination-unreachable, packet-too-big, time-exceeded, parameter-problem } counter accept
            ip protocol icmp icmp type { echo-request, destination-unreachable, router-advertisement, time-exceeded, parameter-problem } counter accept
            ip protocol icmpv6 counter accept
            ip protocol icmp counter accept
            meta l4proto ipv6-icmp counter accept

            udp dport dhcpv6-client counter accept

            tcp dport { 64022, 22, 53, 67, 25565 } counter accept
            udp dport { 64020, 22, 53, 67 } counter accept

            # iifname "iot" ip saddr $iot-ip tcp dport { llmnr } counter accept
            # iifname "iot" ip saddr $iot-ip udp dport { mdns, llmnr } counter accept
            iifname "${lan_if}" tcp dport { llmnr } counter accept
            iifname "${lan_if}" udp dport { mdns, llmnr } counter accept

            counter drop
          }

          # allow all outgoing
          chain output {
            type filter hook output priority 0;
            accept
          }

          chain forward {
            type filter hook forward priority 0;
            accept
          }
        '';
      };

      nat = {
        family = "ip";
        content = ''
          set masq_saddr {
          	type ipv4_addr
          	flags interval
          	elements = { ${cidr} }
          }

          map map_port_ipport {
          	type inet_proto . inet_service : ipv4_addr . inet_service
          }

          chain prerouting {
          	iifname ${lan_if} accept

          	type nat hook prerouting priority dstnat + 1; policy accept;
          	fib daddr type local dnat ip addr . port to meta l4proto . th dport map @map_port_ipport

          	iifname ${wan_if} tcp dport { 22, 80, 443, 25565, 64022 } dnat to ${hosts.beefcake.ip}
          	iifname ${wan_if} udp dport { 64020 } dnat to ${hosts.beefcake.ip}

          	# iifname ${wan_if} tcp dport { 25565 } dnat to 192.168.0.244
          	# iifname ${wan_if} udp dport { 25565 } dnat to 192.168.0.244

          	# router
          	iifname ${wan_if} tcp dport { 2201 } dnat to ${ip}
          }

          chain output {
          	type nat hook output priority -99; policy accept;
          	ip daddr != 127.0.0.0/8 oif "lo" dnat ip addr . port to meta l4proto . th dport map @map_port_ipport
          }

          chain postrouting {
          	type nat hook postrouting priority srcnat + 1; policy accept;
          	oifname ${lan_if} masquerade
          	ip saddr @masq_saddr masquerade
          }
        '';
      };
    };
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

  systemd.network = {
    enable = true;
    links = {
      "${wan_if}" = {
        enable = true;
        matchConfig = {
          MACAddress = "00:01:2e:82:73:59";
        };
        linkConfig = {
          Name = wan_if;
        };
      };
      "${lan_if}" = {
        enable = true;
        matchConfig = {
          MACAddress = "00:01:2e:82:73:5a";
        };
        linkConfig = {
          Name = lan_if;
        };
      };
    };
  };

  services.avahi = {
    enable = true;
    reflector = true;
    allowInterfaces = [
      lan_if
    ];
  };

  system.stateVersion = "24.05";
}
