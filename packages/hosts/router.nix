{
  hardware,
  config,
  lib,
  # outputs,
  pkgs,
  ...
}:
let
in
/*
  NOTE: My goal is to be able to apply most of the common tweaks to the router
  either live on the system for ad-hoc changes (such as forwarding a port for a
  multiplayer game) or to tweak these values just below without reaching deeper
  into the modules' implementation of these configuration values
  NOTE: I could turn this into a cool NixOS module?
  TODO: review https://francis.begyn.be/blog/nixos-home-router
  TODO: more recent: https://github.com/ghostbuster91/blogposts/blob/a2374f0039f8cdf4faddeaaa0347661ffc2ec7cf/router2023-part2/main.md
*/
{
  system.stateVersion = "24.11";

  # hardware
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    initrd.availableKernelModules = [ "xhci_pci" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6ec80156-62e0-4f6f-b6eb-e2f588f88802";
    fsType = "btrfs";
    options = [ "subvol=root" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/6ec80156-62e0-4f6f-b6eb-e2f588f88802";
    fsType = "btrfs";
    options = [ "subvol=nix" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/6ec80156-62e0-4f6f-b6eb-e2f588f88802";
    fsType = "btrfs";
    options = [ "subvol=home" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/7F78-7AE8";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  powerManagement.cpuFreqGovernor = "performance";

  imports = with hardware; [
    common-cpu-intel
    common-pc-ssd
  ];

  environment.systemPackages = with pkgs; [
    iftop
  ];

  sops = {
    defaultSopsFile = ../../secrets/router/secrets.yml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {
      netlify-ddns-password = {
        mode = "0400";
      };
    };
  };
  services.deno-netlify-ddns-client = {
    passwordFile = config.sops.secrets.netlify-ddns-password.path;
  };

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

  lyte = {
    shell.enable = true;
    router = {
      enable = true;
      hostname = "router";
      domain = "h.lyte.dev";
      interfaces = {
        wan.mac = "00:01:2e:82:73:59";
        lan.mac = "00:01:2e:82:73:5a";
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
    };

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
  };
}
