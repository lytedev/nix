{
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.router;
in
{
  options.lyte.router = {
    enable = lib.mkEnableOption "Enable home router functionality";
    hostname = lib.mkOption {
      default = "router";
      description = "The hostname of the router. NOT the FQDN. This value concatenated with the domain will form the FQDN of this router host.";
      type = lib.types.str;
      example = "my-home-router";
    };
    domain = lib.mkOption {
      # default = null;
      description = "The domain of the router.";
      type = lib.types.str;
      example = "lan";
    };

    /*
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
            "a.lyte.dev"
            "atuin.h.lyte.dev"
            "audio.lyte.dev"
            "bw.lyte.dev"
            "files.lyte.dev"
            "finances.h.lyte.dev"
            "git.lyte.dev"
            "grafana.h.lyte.dev"
            "idm.h.lyte.dev"
            "matrix.lyte.dev"
            "nextcloud.h.lyte.dev"
            "nix.h.lyte.dev"
            "onlyoffice.h.lyte.dev"
            "paperless.h.lyte.dev"
            "prometheus.h.lyte.dev"
            "video.lyte.dev"
            "vpn.h.lyte.dev"
          ];
        };
      };
    */
    hosts = lib.mkOption {

    };

    interfaces = {
      wan = {
        name = lib.mkOption {
          default = "wan";
          type = lib.types.str;
        };
        mac = lib.mkOption {
          type = lib.types.str;
        };
      };
      lan = {
        name = lib.mkOption {
          default = "lan";
          type = lib.types.str;
        };
        mac = lib.mkOption {
          type = lib.types.str;
        };
      };
    };

    # TODO: would be nice to support multiple VLANs?
    ipv4 = {
      address = lib.mkOption {
        default = "192.168.0.1";
        description = "The IPv4 address of the router.";
        type = lib.types.str;
        example = "10.0.0.1";
      };
      cidr = lib.mkOption {
        # TODO: derive IPv4 from CIDR?
        description = ''The CIDR to route. If null, will use "''${config.lyte.router.ipv4}/16".'';
        default = null;
        example = "10.0.0.0/8";
        # type = lib.types.str;
        defaultText = ''''${config.lyte.router.ipv4}/16'';
      };
      netmask = lib.mkOption {
        # TODO: derive from CIDR?
        default = "255.255.255.0";
        type = lib.types.str;
      };
      dhcp-lease-space = {
        min = lib.mkOption {
          default = "192.168.0.30";
          type = lib.types.str;
        };
        max = lib.mkOption {
          default = "192.168.0.250";
          type = lib.types.str;
        };
      };
    };
  };
  config = lib.mkIf cfg.enable (
    let
      cidr = lib.defaultTo "${cfg.ipv4.address}/16" cfg.ipv4.cidr;
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

        nftables = {
          enable = true;
          checkRuleset = true;
          flushRuleset = true;

          ruleset = ''
            table inet filter {
              ## set LANv4 {
              ##   type ipv4_addr
              ##   flags interval
              ##   elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
              ## }
              ## set LANv6 {
              ##   type ipv6_addr
              ##   flags interval
              ##   elements = { fd00::/8, fe80::/10 }
              ## }
              ## TODO: maybe tailnet?

              ## chain my_input_lan {
              ##   udp sport 1900 udp dport >= 1024 meta pkttype unicast limit rate 4/second burst 20 packets accept comment "Accept UPnP IGD port mapping reply"
              ##   udp sport netbios-ns udp dport >= 1024 meta pkttype unicast accept comment "Accept Samba Workgroup browsing replies"
              ## }

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
                udp dport { 34197 } accept comment "Allow Factorio server connections (see nat prerouting)"

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

              ## chain forward {
              ##   type filter hook forward priority filter; policy drop;

              ##   iifname { "${lan}" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
              ##   iifname { "tailscale0" } oifname { "${wan}" } accept comment "Allow trusted LAN to WAN"
              ##   iifname { "${wan}" } oifname { "${lan}" } ct state { established, related } accept comment "Allow established back to LAN"
              ## }
            }

            table ip nat {
              chain prerouting {
                type nat hook prerouting priority dstnat;

                iifname ${lan} accept
                iifname tailscale0 accept

                iifname ${wan} tcp dport {22} dnat to ${cfg.hosts.beefcake.ip}
                iifname ${wan} tcp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
                iifname ${wan} udp dport {80, 443} dnat to ${cfg.hosts.beefcake.ip}
                iifname ${wan} tcp dport {26966} dnat to ${cfg.hosts.beefcake.ip}
                iifname ${wan} tcp dport {25565} dnat to ${cfg.hosts.bald.ip}
                iifname ${wan} udp dport {25565} dnat to ${cfg.hosts.bald.ip}
                iifname ${wan} udp dport {34197} dnat to ${cfg.hosts.beefcake.ip}
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
        # wait-online.anyInterface = true;

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
            ++ (lib.attrsets.mapAttrsToList (
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
            ++ (lib.lists.flatten (
              lib.attrsets.mapAttrsToList (
                name:
                {
                  ip,
                  additionalHosts ? [ ],
                  identifier ? name,
                  time ? "12h",
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
}
