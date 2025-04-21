/*
  if ur fans get loud:

  # enable manual fan control
  sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x01 0x00

  # set fan speed to last byte as decimal
  sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x02 0xff 0x00
*/
{
  /*
    inputs,
    outputs,
  */
  lib,
  config,
  pkgs,
  hardware,
  ...
}:
{
  system.stateVersion = "24.05";
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
  };

  boot = {
    zfs.extraPools = [ "zstorage" ];
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    # kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "nohibernate" ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/992ce55c-7507-4d6b-938c-45b7e891f395";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/B6C4-7CF4";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    "/nix" = {
      device = "zstorage/nix";
      fsType = "zfs";
    };
  };

  networking = {
    hostId = "541ede55";
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
    tailscale.useRoutingFeatures = "server";
  };

  sops = {
    defaultSopsFile = ../../secrets/beefcake/secrets.yml;
    secrets = {
      netlify-ddns-password.mode = "0400";
      nix-cache-priv-key.mode = "0400";
    };
  };

  podman.enable = true;

  services.deno-netlify-ddns-client = {
    enable = true;
    passwordFile = config.sops.secrets.netlify-ddns-password.path;
    username = "beefcake.h";
  };

  environment.systemPackages = with pkgs; [
    aria2
    restic
    btrfs-progs
    zfs
    smartmontools
    htop
    bottom
    curl
    xh
  ];

  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };

  /*
    TODO: non-root processes and services that access secrets need to be part of
    the 'keys' group

    systemd.services.some-service = {
      serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
    };
    or
    users.users.example-user.extraGroups = [ config.users.groups.keys.name ];

    TODO: declarative directory quotas? for storage/$USER and /home/$USER
  */

  /*
    # https://github.com/NixOS/nixpkgs/blob/04af42f3b31dba0ef742d254456dc4c14eedac86/nixos/modules/services/misc/lidarr.nix#L72
    services.lidarr = {
      enable = true;
      dataDir = "/storage/lidarr";
    };

    services.radarr = {
      enable = true;
      dataDir = "/storage/radarr";
    };

    services.sonarr = {
      enable = true;
      dataDir = "/storage/sonarr";
    };

    services.bazarr = {
      enable = true;
      listenPort = 6767;
    };

    networking.firewall.allowedTCPPorts = [9876 9877];
    networking.firewall.allowedUDPPorts = [9876 9877];
    networking.firewall.allowedUDPPortRanges = [
      {
        from = 27000;
        to = 27100;
      }
    ];
  */

  imports =
    [
      hardware.common-cpu-intel
    ]
    ++ (builtins.map import [
      ./beefcake/nix-serve.nix
      ./beefcake/headscale.nix
      ./beefcake/soju.nix
      ./beefcake/nextcloud.nix
      ./beefcake/plausible.nix
      ./beefcake/clickhouse.nix
      ./beefcake/family-storage.nix
      ./beefcake/daniel.nix
      ./beefcake/jellyfin.nix
      ./beefcake/daniel.nix
      ./beefcake/postgres.nix
      ./beefcake/other-users.nix
      ./beefcake/restic.nix
      ./beefcake/caddy.nix
      ./beefcake/forgejo.nix
      ./beefcake/vaultwarden.nix
      ./beefcake/atuin.nix
      ./beefcake/kanidm.nix
      ./beefcake/minecraft-server-containers.nix
      ./beefcake/audiobookshelf.nix
      ./beefcake/prometheus.nix
      ./beefcake/grafana.nix
      ./beefcake/paperless.nix
      ./beefcake/actual.nix
      ./beefcake/factorio-servers.nix
      ./beefcake/conduwuit.nix
      ./beefcake/element-web.nix
    ]);
}
