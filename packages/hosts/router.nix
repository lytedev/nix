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

  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };

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

      openPorts = {
        tcp = {
          "Accept SSH to router" = 2201;
          "Accept DNS" = 53;
        };
        udp = {
          "Accept DNS" = 53;
        };
      };

      # TODO: nftables

      hosts = {
        dragon = {
          ip = "192.168.0.10";
          nat.tcp.SSH = 4822;
        };
        bald = {
          ip = "192.168.0.11";
          nat.tcp.minecraft = 25565;
          additionalHosts = [
            "ourcraft.lyte.dev"
          ];
        };
        beefcake = {
          ip = "192.168.0.9";
          nat = {
            tcp = {
              "SSH" = 22;
              "HTTP" = 80;
              "HTTPS" = 443;
              "Minecraft Flanilla Creative" = 26968;
            };
            udp = {
              "QUIC" = [
                80
                443
              ];
              "Factorio" = 34197;
            };
          };
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
    };
  };
}
