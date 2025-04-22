{
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.router;
  inherit (builtins) concatStringsSep toString;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    defaultTo
    ;
  inherit (lib.attrsets) mapAttrsToList mapAttrs';
  inherit (lib.lists) flatten toList;

in
{
  options.lyte.router = {
    enable = mkEnableOption "Enable home router functionality";
    hostname = mkOption {
      default = "router";
      description = "The hostname of the router. NOT the FQDN. This value concatenated with the domain will form the FQDN of this router host.";
      type = types.str;
      example = "my-home-router";
    };
    domain = mkOption {
      # default = null;
      description = "The domain of the router.";
      type = types.str;
      example = "lan";
    };

    openPorts = mkOption { };
    hosts = mkOption { };

    interfaces = {
      wan = {
        name = mkOption {
          default = "wan";
          type = types.str;
        };
        mac = mkOption {
          type = types.str;
        };
      };
      lan = {
        name = mkOption {
          default = "lan";
          type = types.str;
        };
        mac = mkOption {
          type = types.str;
        };
      };
    };

    # TODO: would be nice to support multiple VLANs?
    ipv4 = {
      address = mkOption {
        default = "192.168.0.1";
        description = "The IPv4 address of the router.";
        type = types.str;
        example = "10.0.0.1";
      };
      cidr = mkOption {
        # TODO: derive IPv4 from CIDR?
        description = ''The CIDR to route. If null, will use "''${config.lyte.router.ipv4}/16".'';
        default = null;
        example = "10.0.0.0/8";
        # type = types.str;
        defaultText = ''''${config.lyte.router.ipv4}/16'';
      };
      netmask = mkOption {
        # TODO: derive from CIDR?
        default = "255.255.255.0";
        type = types.str;
      };
      dhcp-lease-space = {
        min = mkOption {
          default = "192.168.0.30";
          type = types.str;
        };
        max = mkOption {
          default = "192.168.0.250";
          type = types.str;
        };
      };
    };
  };
  config = mkIf cfg.enable (
    let
      cidr = defaultTo "${cfg.ipv4.address}/16" cfg.ipv4.cidr;
      wan = cfg.interfaces.wan.name;
      lan = cfg.interfaces.lan.name;
    in
    {
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true;

        "net.ipv4.conf.default.rp_filter" = 1;
        "net.ipv4.conf.${cfg.interfaces.wan.name}.rp_filter" = 1;
        "net.ipv4.conf.${cfg.interfaces.lan.name}.rp_filter" = 0;

        "net.ipv6.conf.${cfg.interfaces.wan.name}.accept_ra" = 2;
        "net.ipv6.conf.${cfg.interfaces.wan.name}.autoconf" = 1;

        "net.ipv6.conf.all.use_tempaddr" = 2;
        "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 2;
        "net.ipv6.conf.${cfg.interfaces.wan.name}.use_tempaddr" = 2;

        # "net.ipv6.conf.${interfaces.wan.name}.addr_gen_mode" = 2;
      };

      networking = {
        hostName = cfg.hostname;
        # disable some of the sane defaults
        # TODO: detect conflicts with NixOS firewall options? this may be done for us?
        useDHCP = false;
        firewall.enable = false;

        # use systemd.network for network interface configuration
        useNetworkd = true;

        # maybe we need this?
        nat.enable = true;

        extraHosts = ''
          127.0.0.1 localhost
          127.0.0.2 ${cfg.hostname}.${cfg.domain} ${cfg.hostname}
          ${cfg.ipv4.address} ${cfg.hostname}.${cfg.domain} ${cfg.hostname}

          ::1 localhost ip6-localhost ip6-loopback
          ff02::1 ip6-allnodes
          ff02::2 ip6-allrouters
        '';

        # tcp dport 2201 accept comment "Accept SSH on port 2201"
        # tcp dport 53 accept comment "Accept DNS"
        # udp dport 53 accept comment "Accept DNS"

        # tcp dport { 80, 443 } accept comment "Allow HTTP/HTTPS to server (see nat prerouting)"
        # udp dport { 80, 443 } accept comment "Allow QUIC to server (see nat prerouting)"

        nftables =
          let
            mkOpenPortRule =
              protocol: rules:
              mapAttrsToList (
                name: ports:
                ''${protocol} dport {${concatStringsSep ", " (map toString (toList ports))}} accept comment "${name}"''
              ) rules;

            tcpRulesString = mkOpenPortRule "tcp" cfg.openPorts.tcp;
            udpRulesString = mkOpenPortRule "udp" cfg.openPorts.udp;

            hostRules = flatten (
              mapAttrsToList (
                hostname:
                {
                  nat ? { },
                  ...
                }:
                mapAttrsToList (
                  protocol: rules:
                  mkOpenPortRule protocol (
                    mapAttrs' (name: value: {
                      name = "NAT ${name} to ${hostname}";
                      value = value;
                    }) rules
                  )
                ) nat
              ) cfg.hosts
            );

            acceptPorts = flatten [
              tcpRulesString
              udpRulesString
              hostRules
            ];

            # iifname ${wan} tcp dport {22} dnat to ${cfg.hosts.beefcake.ip}
            # iifname ${wan} tcp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
            # iifname ${wan} udp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
            # iifname ${wan} tcp dport {26966} dnat to ${cfg.hosts.beefcake.ip}
            # iifname ${wan} tcp dport {25565} dnat to ${cfg.hosts.bald.ip}
            # iifname ${wan} udp dport {25565} dnat to ${cfg.hosts.bald.ip}
            # iifname ${wan} udp dport {34197} dnat to ${cfg.hosts.beefcake.ip}
            #

            mkNatRule =
              protocol: ports: address: comment:
              ''iifname ${wan} ${protocol} dport {${concatStringsSep ", " (map toString (flatten (toList ports)))}} dnat to ${address} # ${comment}'';

            natPorts = flatten (
              mapAttrsToList (
                hostname:
                {
                  ip,
                  nat ? { },
                  ...
                }:
                # TODO: embed comment?
                mapAttrsToList (
                  protocol: rules: mkNatRule protocol (mapAttrsToList (_: ports: ports) rules) ip "comment"
                ) nat
              ) cfg.hosts
            );
          in
          {
            enable = true;
            checkRuleset = true;
            flushRuleset = true;

            /*
              set LANv4 {
                type ipv4_addr
                flags interval
                elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
              }
              set LANv6 {
                type ipv6_addr
                flags interval
                elements = { fd00::/8, fe80::/10 }
              }
              TODO: maybe tailnet?

              chain my_input_lan {
                udp sport 1900 udp dport >= 1024 meta pkttype unicast limit rate 4/second burst 20 packets accept comment "Accept UPnP IGD port mapping reply"
                udp sport netbios-ns udp dport >= 1024 meta pkttype unicast accept comment "Accept Samba Workgroup browsing replies"
              }

              chain forward {
                type filter hook forward priority filter; policy drop;

                iifname { "${lan}" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
                iifname { "tailscale0" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
                iifname { "${wan}" } oifname { "${lan}" } ct state { established, related } accept comment "Allow established back to LAN"
              }
            */

            ruleset = ''
              table inet filter {
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

                  ${concatStringsSep "\n    " acceptPorts}

                  iifname "${lan}" accept comment "Allow local network to access the router"
                  iifname "tailscale0" accept comment "Allow local network to access the router"

                  ## ip6 saddr @LANv6 jump my_input_lan comment "Connections from private IP address ranges"
                  ## ip saddr @LANv4 jump my_input_lan comment "Connections from private IP address ranges"

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
              }

              table ip nat {
                chain prerouting {
                  type nat hook prerouting priority dstnat;

                  iifname ${lan} accept
                  iifname tailscale0 accept

                  ${concatStringsSep "\n    " (builtins.trace (toString natPorts) natPorts)}

                  # iifname ${wan} tcp dport {22} dnat to ${cfg.hosts.beefcake.ip}
                  # iifname ${wan} tcp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
                  # iifname ${wan} udp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
                  # iifname ${wan} tcp dport {26966} dnat to ${cfg.hosts.beefcake.ip}
                  # iifname ${wan} tcp dport {25565} dnat to ${cfg.hosts.bald.ip}
                  # iifname ${wan} udp dport {25565} dnat to ${cfg.hosts.bald.ip}
                  # iifname ${wan} udp dport {34197} dnat to ${cfg.hosts.beefcake.ip}
                }

                chain postrouting {
                  type nat hook postrouting priority 100; policy accept;
                  oifname "${wan}" masquerade
                }
              }
            '';
          };
      };

      systemd.network = {
        enable = true;
        wait-online.anyInterface = true;

        # configure known names for the network interfaces by their mac addresses
        links = {
          "20-${wan}" = {
            enable = true;
            matchConfig = {
              MACAddress = cfg.interfaces.wan.mac;
            };
            linkConfig = {
              Name = cfg.interfaces.wan.name;
            };
          };
          "30-${lan}" = {
            enable = true;
            matchConfig = {
              MACAddress = cfg.interfaces.lan.mac;
            };
            linkConfig = {
              Name = cfg.interfaces.lan.name;
            };
          };
        };

        # configure networks for the interfaces
        networks = {
          # LAN configuration is very simple and mostly forwarded between
          # TODO: IPv6
          "50-${lan}" = {
            matchConfig.Name = "${lan}";
            linkConfig = {
              RequiredForOnline = "enslaved";
            };
            address = [
              cidr
            ];
            networkConfig = {
              ConfigureWithoutCarrier = true;
              IPv6SendRA = true;
              DHCPPrefixDelegation = true;
            };
          };

          /*
            WAN configuration requires DHCP to get addresses
            we also disable some options to be certain we retain as much networking
            control as we reasonably can, such as not letting the ISP determine our
            hostname or DNS configuration
          */
          # TODO: IPv6 (prefix delegation)
          "40-${wan}" = {
            matchConfig.Name = "${wan}";
            networkConfig = {
              DHCP = true;
              /*
                IPv6AcceptRA = true;
                IPv6PrivacyExtensions = true;
                IPForward = true;
              */
            };
            dhcpV6Config = {
              /*
                ForceDHCPv6PDOtherInformation = true;
                UseHostname = false;
                UseDNS = false;
                UseNTP = false;
              */
              # PrefixDelegationHint = "::/56";
            };
            dhcpV4Config = {
              Hostname = cfg.hostname;

              # ignore many things our ISP may suggest
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
      services.fail2ban.enable = true;
      services.dnsmasq = {
        enable = true;
        settings = {
          listen-address = "::,127.0.0.1,${cfg.ipv4.address}";
          port = 53;

          /*
            dhcp-authoritative = true;
            dnssec = true;
          */
          enable-ra = true;

          server = [
            "1.1.1.1"
            "9.9.9.9"
            "8.8.8.8"
          ];

          domain-needed = true;
          bogus-priv = true;
          no-resolv = true;

          cache-size = "10000";

          dhcp-range = with cfg.ipv4.dhcp-lease-space; [
            "${lan},${min},${max},${cfg.ipv4.netmask},24h"
            "::,constructor:${lan},ra-stateless,ra-names,4h"
          ];
          except-interface = wan;
          interface = lan;
          dhcp-host =
            [
            ]
            ++ (mapAttrsToList (
              name:
              {
                ip,
                identifier ? name,
                time ? "12h",
                ...
              }:
              "${name},${ip},${identifier},${time}"
            ) cfg.hosts);

          address =
            [
              "/${cfg.hostname}.${cfg.domain}/${cfg.ipv4.address}"
            ]
            ++ (flatten (
              mapAttrsToList (
                name:
                {
                  ip,
                  additionalHosts ? [ ],
                  # identifier ? name,
                  # time ? "12h",
                  ...
                }:
                [
                  "/${name}.${cfg.domain}/${ip}"
                  (lib.lists.forEach additionalHosts (h: "/${h}/${ip}"))
                ]
              ) cfg.hosts
            ));

          # local domains
          local = "/lan/";
          domain = "lan";
          expand-hosts = true;

          # don't use /etc/hosts as this would advertise surfer as localhost
          no-hosts = true;
        };
      };
    }
  );

  # NOTE: see flake.nix 'nnf.nixosModules.default'
  /*
    nftables.firewall = let
      me = config.networking.nftables.firewall.localZoneName;
    in {
      enable = true;
      snippets.nnf-common.enable = true;

      zones = {
        ${interfaces.wan.name} = {
          interfaces = [interfaces.wan.name interfaces.lan.name];
        };
        ${interfaces.lan.name} = {
          parent = interfaces.wan.name;
          ipv4Addresses = [cidr];
        };
        ## banned = {
        ##   ingressExpression = [
        ##     "ip saddr @banlist"
        ##     "ip6 saddr @banlist6"
        ##   ];
        ##   egressExpression = [
        ##     "ip daddr @banlist"
        ##     "ip6 daddr @banlist6"
        ##   ];
        ## };
      };

      rules = {
        dhcp = {
          from = "all";
          to = [hosts.beefcake.ip];
          allowedTCPPorts = [67];
          allowedUDPPorts = [67];
        };
        http = {
          from = "all";
          to = [me];
          allowedTCPPorts = [80 443];
        };
        router-ssh = {
          from = "all";
          to = [me];
          allowedTCPPorts = [2201];
        };
        server-ssh = {
          from = "all";
          to = [hosts.beefcake.ip];
          allowedTCPPorts = [22];
        };
      };
    };
  */

  /*
    dnsmasq serves as our DHCP and DNS server
    almost all the configuration should be derived from the values at the top of
    this file
  */

  /*
    since the home network reserves port 22 for ssh to the big server and to
    gitea, the router uses port 2201 for ssh
  */
  /*
    NOTE: everything from here on is deprecated or old stuff

    TODO: may not be strictly necessary for IPv6?
    TODO: also may not even be the best implementation?
    services.radvd = {
      enable = false;
      ## NOTE: this config is just the default arch linux config I think and may
      ## need tweaking? this is what I had on the arch linux router, though :shrug:
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

    TODO: old config, should be deleted ASAP
    services.dnsmasq = {
      enable = false;
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
          "lan,${dhcp_lease_space.min},${dhcp_lease_space.max},${netmask},10m"
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

    TODO: old config, should be deleted ASAP
    nftables = {
      enable = false;
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

              ## iifname "iot" ip saddr $iot-ip tcp dport { llmnr } counter accept
              ## iifname "iot" ip saddr $iot-ip udp dport { mdns, llmnr } counter accept
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

              ## iifname ${wan_if} tcp dport { 25565 } dnat to 192.168.0.244
              ## iifname ${wan_if} udp dport { 25565 } dnat to 192.168.0.244

              ## router
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

    TODO: also want to try to avoid using dhcpcd for IPv6 since systemd-networkd
    should be sufficient?
    dhcpcd = {
      enable = false;
      extraConfig = ''
        duid

        ## No way.... https://github.com/NetworkConfiguration/dhcpcd/issues/36#issuecomment-954777644
        ## issues caused by guests with oneplus devices
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
          ## option rapid_commit
          ## ia_na 1
          ia_pd 1 ${lan_if}

        interface ${lan_if}
          static ip_address=${cidr}
          static routers=${ip}
          static domain_name_servers=${ip}
      '';
    };
  */
}
