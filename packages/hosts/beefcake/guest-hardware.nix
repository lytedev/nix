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

  # ---- zstorage datasets via virtiofs (Model B). The host exposes each share
  #      with a tag; the guest mounts them. xattr/acl already satisfied by the
  #      host datasets. (Tags/paths finalized with the host NixVirt domain.) ----
  # TODO(next): declare the virtiofs mounts once the host domain fixes the tags:
  #   fileSystems."/storage" = { device = "zstorage"; fsType = "virtiofs"; ... };
  #   fileSystems."/var/lib/containers" = { fsType = "virtiofs"; ... };
  #   fileSystems."/var/lib/private"    = { fsType = "virtiofs"; ... };
  # Kept as a marker so the guest config evaluates before the host side lands.

  # ---- networking: a plain virtio NIC. The host tap carries the service MAC,
  #      so the guest just DHCPs and lands on 192.168.0.9 via the reservation.
  #      beefcake/networking.nix already sets hostId 541ede55 + tailscale. ----
  networking.useDHCP = lib.mkForce true;
  # The bare-metal NAT/exit-node config keys off eno1; the guest's iface differs.
  # TODO(next): reconcile networking.nix's eno1-specific nat.externalInterface
  # with the guest's virtio iface name (or set a stable iface name via udev).
}
