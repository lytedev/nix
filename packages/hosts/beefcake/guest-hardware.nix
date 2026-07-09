# beefcake-guest hardware layer (Phase 3, design §2). Applied via
# `beefcake.extendModules { modules = [ ./guest-hardware.nix ]; }` — reuses ALL
# of beefcake's services + impermanence + sops and swaps ONLY the bare-metal
# hardware (packages/hosts/beefcake/hardware.nix) for the libvirt guest:
#   - virtio-blk root (a host zvol) instead of the SSD mirror + mpt3sas HBA
#   - /nix as the proven OverlayFS (RO base + RW per-slot upper) — the
#     overlay-boot M2 mechanism (prototypes/.../overlay-boot-config.nix)
#   - zstorage datasets via virtiofs shares from the host (Model B) — the guest
#     never imports the pool
#   - a virtio NIC; the host tap carries the service MAC (b8:ca:3a:6d:2d:24) so
#     the guest keeps 192.168.0.9 + the v6 GUA via the router reservation
#
# NOT deployed — validated on dragon via the nested beefcake-host prototype.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # ---- undo the bare-metal hardware.nix ----
  # The guest does NOT own zstorage (host shares datasets via virtiofs).
  boot.zfs.extraPools = lib.mkForce [ ];
  # The guest's pool was created by the disko image-build VM under a FOREIGN
  # hostid (the pool keeps its creation hostid forever), so every guest boot
  # must force-import its own root pool. Safe: inside the VM only vda is
  # visible. (Bug #7 — caught in cutover-prep review.)
  boot.zfs.forceImportRoot = true;
  # Serial-less virtio disks have NO /dev/disk/by-id entries, and the initrd's
  # `zpool import` on the default by-id devNodes waits forever (the proven
  # rollback/overlay-boot gotcha). by-path always exists. (Bug #8.)
  boot.zfs.devNodes = "/dev/disk/by-path";
  # virtio, not the SAS HBA.
  boot.initrd.availableKernelModules = lib.mkForce [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "sr_mod"
    "sd_mod"
  ];
  # No dual-ESP mirror on a single virtio disk.
  boot.loader.systemd-boot.extraInstallCommands = lib.mkForce "";

  # ---- disks: virtio-blk. Root stays impermanent (impermanence.nix already
  #      mkForces / = rpool/local/root + /persist = rpool/persist); those live
  #      on the guest's OS zvol pool (rpool). We override /boot and /nix. ----
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  # /nix: base closure on rpool/local/nix (the overlay LOWER), overlaid with a
  # per-slot RW upper on rpool/local/nix-upper (the M2 mechanism). Replaces
  # hardware.nix's /nix = zstorage/nix.
  fileSystems."/nix" = lib.mkForce {
    device = "rpool/local/nix";
    fsType = "zfs";
    neededForBoot = true;
  };
  fileSystems."/nix-upper" = {
    device = "rpool/local/nix-upper";
    fsType = "zfs";
    neededForBoot = true;
  };

  # ---- /nix/store OverlayFS (proven by overlay-boot M2): early stage-2, after
  #      the ZFS mounts, before nix-daemon. ----
  boot.kernelModules = [ "overlay" ];
  systemd.services.overlay-nix-store = {
    description = "Overlay /nix/store (RO base lower + RW per-slot upper)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "zfs-mount.service"
      "local-fs.target"
    ];
    requires = [ "zfs-mount.service" ];
    before = [ "nix-daemon.service" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euxo pipefail
      if findmnt -n -o FSTYPE /nix/store | tail -n1 | grep -qx overlay; then
        echo "already overlaid"; exit 0
      fi
      mkdir -p /nix/.store-lower /nix-upper/store /nix-upper/work
      mount --bind /nix/store /nix/.store-lower
      mount -t overlay overlay \
        -o lowerdir=/nix/.store-lower,upperdir=/nix-upper/store,workdir=/nix-upper/work \
        /nix/store
    '';
  };

  # ---- zstorage datasets via virtiofs (Model B) — mounted by the tags the host
  #      domain exposes (beefcake-host.nix: storage / containers / varlib-private).
  #      The host datasets carry xattr=sa + posixacl already. ----
  fileSystems."/storage" = {
    device = "storage";
    fsType = "virtiofs";
  };
  fileSystems."/var/lib/containers" = {
    device = "containers";
    fsType = "virtiofs";
  };
  fileSystems."/var/lib/private" = {
    device = "varlib-private";
    fsType = "virtiofs";
  };

  # ---- networking: the domain gives the guest's virtio NIC the service MAC
  #      (b8:ca:3a:6d:2d:24). Name that NIC "eno1" by MAC so ALL of
  #      beefcake/networking.nix (nat.externalInterface=eno1, tailscale exit
  #      node, the 192.168.0.9 DHCP reservation, hostId 541ede55) applies
  #      UNCHANGED — the guest is beefcake as far as the LAN is concerned. ----
  systemd.network.links."10-eno1" = {
    matchConfig.MACAddress = "b8:ca:3a:6d:2d:24";
    linkConfig.Name = "eno1";
  };
}
