# beefcake-host — Phase 3 thin hypervisor (design doc §2, open-Q#4 = libvirt +
# NixVirt). This is the box's REAL OS after the cutover: a deliberately tiny,
# impermanent NixOS host whose only jobs are (1) own the disks, (2) run today's
# beefcake config as a libvirt GUEST, (3) bridge the guest onto the LAN with the
# service MAC. Everything that is "beefcake the service host" lives in the guest.
#
# STATUS: increment 1 — the thin host itself (boot/disk/net/libvirtd/monitoring),
# NOT YET DEPLOYED. Validated on dragon via a nested VM. The GUEST domain
# (beefcake-guest, /nix overlay per overlay-nix M1, zstorage virtiofs shares,
# service-MAC tap) is the NEXT increment; wired in via NixVirt below where marked.
#
# Registered in packages/hosts/default.nix with the impermanence + NixVirt
# modules as extraModules.
{
  config,
  lib,
  pkgs,
  hardware,
  nixvirt,
  ...
}:
let
  # The guest domain, declared with NixVirt. storage_vol is the guest OS disk —
  # a zvol on the host that holds the guest's rpool (root@blank + the /nix base
  # closure + the per-slot /nix-upper + /persist). Provisioned at cutover by
  # building beefcake-guest into an image and writing it to the zvol (runbook).
  # The blue slot is the initial active guest; green is added in Phase 4.
  guestBase = nixvirt.lib.domain.templates.linux {
    name = "beefcake-blue";
    uuid = "b1000000-beef-cafe-0000-000000000001";
    memory = {
      count = 200;
      unit = "GiB";
    };
    vcpu = {
      count = 36;
    };
    storage_vol = "/dev/zvol/rpool/beefcake-blue";
    bridge_name = "br0";
    net_iface_mac = "b8:ca:3a:6d:2d:24"; # the SERVICE MAC → keeps 192.168.0.9
  };
  # virtiofs share of a host zstorage dataset into the guest (Model B). The
  # guest mounts it by the target `dir` tag (see guest-hardware.nix).
  virtiofsShare = hostDir: tag: {
    type = "mount";
    accessmode = "passthrough";
    driver = {
      name = "virtiofs";
    };
    binary = {
      path = "${pkgs.virtiofsd}/bin/virtiofsd";
      xattr = true;
    };
    source = {
      dir = hostDir;
    };
    target = {
      dir = tag;
    };
  };
  guestDomain = guestBase // {
    # virtiofs requires guest RAM be shared (memfd + shared access).
    memoryBacking = {
      source = {
        type = "memfd";
      };
      access = {
        mode = "shared";
      };
    };
    devices = guestBase.devices // {
      filesystem = [
        (virtiofsShare "/storage" "storage")
        (virtiofsShare "/var/lib/containers" "containers")
        (virtiofsShare "/var/lib/private" "varlib-private")
      ];
    };
  };
in
{
  imports = [
    hardware.common-cpu-intel
  ];

  networking.hostName = "beefcake-host";
  # The HOST's own hostId — DISTINCT from the guest's (541ede55). The host
  # imports zstorage, so this is the id that pool carries; the guest never
  # imports zstorage (it gets datasets via virtiofs), so the two never collide.
  networking.hostId = "beef00a1";

  # ---- boot / disk: same hardware as beefcake (Dell R720xd), SSD ZFS mirror
  #      root, dual ESPs, HBA + KVM. Mirrors packages/hosts/beefcake/hardware.nix
  #      but WITHOUT declaring /nix on zstorage — the host's /nix rides its own
  #      root pool (tiny closure); zstorage is imported for SHARING to the guest,
  #      not for the host's own /nix. ----
  boot = {
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas" # the one IT-mode HBA driving every disk
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    # intel_iommu on for the Phase-5 HBA-passthrough option (BIOS VT-d already
    # enabled); harmless otherwise.
    kernelParams = [
      "nohibernate"
      "intel_iommu=on"
    ];
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 20;
    loader.efi.canTouchEfiVariables = true;
    # Mirror ESP-A onto ESP-B after install so either SSD boots (as beefcake).
    loader.systemd-boot.extraInstallCommands = ''
      espB=/dev/disk/by-partlabel/ESP-B
      if [ -e "$espB" ]; then
        m=$(mktemp -d)
        ${pkgs.util-linux}/bin/mount "$espB" "$m"
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ "$m"/
        ${pkgs.util-linux}/bin/umount "$m"
        rmdir "$m"
      fi
    '';
  };

  # The host root is impermanent on its own rpool dataset. lyte.impermanence
  # (packages/hosts/beefcake/impermanence.nix is beefcake-specific; the host
  # reuses the SAME proven mechanism — @blank rollback initrd unit + /persist).
  # TODO(increment): factor the impermanence.nix mechanism into a shared module
  # so beefcake-host and beefcake(guest) both consume it instead of copying.
  # For now the host's persist set is intentionally tiny (identity + libvirt).
  fileSystems = {
    "/" = {
      device = "rpool/local/root";
      fsType = "zfs";
    };
    "/persist" = {
      device = "rpool/persist";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP-A";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    "/nix" = {
      device = "rpool/local/nix";
      fsType = "zfs";
    };
  };

  # Host owns zstorage: import it (do NOT mount its datasets on the host beyond
  # what it shares) so the host can virtiofs-share datasets into the guest.
  boot.zfs.extraPools = [ "zstorage" ];

  # ---- networking: br0 enslaves eno1; the guest's virtio NIC rides br0 with
  #      the SERVICE MAC (b8:ca:3a:6d:2d:24) to keep 192.168.0.9 + the v6 GUA.
  #      The HOST takes its OWN management address on the free eno2. ----
  networking = {
    useDHCP = false;
    bridges.br0.interfaces = [ "eno1" ];
    # Host management on a separate physical port so host + guest never contend
    # for the service MAC/IP. (eno2/3/4 are unplugged today — plug eno2 for mgmt,
    # or the host can also take a second address on br0 with its own MAC.)
    interfaces.eno2.useDHCP = true;
    # br0 itself needs no host IP (the guest owns the service IP on it); give the
    # host a link only if you want host-on-br0 access — kept off to avoid MAC/IP
    # contention with the guest.
  };

  # ---- virtualization: libvirt + NixVirt (design open-Q#4) ----
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.swtpm.enable = true;
    onShutdown = "shutdown"; # clean guest poweroff (DD6: never SIGTERM the VMM)
  };
  # virtiofsd for sharing host zstorage datasets into the guest (Model B).
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  # The guest domain, declared (NixVirt). `active` autostarts the blue slot; its
  # OS closure is beefcake-guest (packages/hosts/beefcake/guest-hardware.nix),
  # written to the /dev/zvol/rpool/beefcake-blue disk at cutover. virtiofs shares
  # feed it the host's zstorage datasets; the tap carries the service MAC.
  # (Green slot + the cutover tool are Phase 4.)
  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system".domains = [
      {
        active = true;
        definition = nixvirt.lib.domain.writeXML guestDomain;
      }
    ];
  };

  # ---- monitoring: hardware lives with the host (smartd/IPMI/node-exporter),
  #      shipped to the guest's OpenObserve (design §5). ----
  services.smartd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # ---- minimal: sshd for host access; NO beefcake services (those are the
  #      guest). Host access is the guest-independent recovery path (§5). ----
  services.openssh.enable = true;

  # The host's /persist set is deliberately tiny: its identity + libvirt state
  # + the active-slot marker. (Guest state is the guest's problem.)
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [ ];
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/libvirt" # domain defs / nvram / swtpm state
    ];
  };

  system.stateVersion = "26.05";
}
