# P4-integration: the MINI GUEST — overlay-boot-config (the proven M2 bootable
# image: impermanent root + OverlayFS /nix) extended with exactly the mechanisms
# packages/hosts/beefcake/guest-hardware.nix adds for the real guest:
#   - a virtiofs mount by tag ("storage") — Model B share from the thin host
#   - the virtio NIC renamed "eno1" by the SERVICE MAC (b8:ca:3a:6d:2d:24 — safe
#     here: it only ever exists on the outer VM's private bridge, never the LAN)
#   - DHCP on it (the outer host's dnsmasq plays the router's MAC reservation)
# This is beefcake-guest in miniature; what boots here validates the guest side
# of the thin-host integration.
{ lib, ... }:
{
  imports = [ ./overlay-boot-config.nix ];

  services.qemuGuest.enable = true; # domfsfreeze (mirrors guest-hardware.nix)

  networking.hostName = lib.mkForce "mini-guest";

  # Phase-4 persist architecture (mirrors packages/hosts/beefcake/
  # guest-hardware.nix): /persist comes from the SHARED persist pool on vdb —
  # NOT the in-image rpool/safe/persist. Identity/state travel with the pool;
  # slot OS zvols are disposable. The pool is created by the thin host
  # (matching hostid), so no force-import needed.
  fileSystems."/persist" = lib.mkForce {
    device = "bpersist/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  # The in-image safe/persist (from overlay-boot-config's disko) has a
  # disko-native mountpoint=/persist -> its ZFS property is /persist, so
  # `zfs mount -a` remounts it OVER the shared bpersist mount (found live:
  # /persist stacked bpersist THEN safe/persist). Neutralize it to legacy so
  # only the bpersist mount stands — mirrors the real guest-image-disko, whose
  # persist dataset is legacy-at-creation. (Production guest is already immune;
  # this keeps the mini test faithful.)
  disko.devices.zpool.rpool.datasets."safe/persist" = {
    mountpoint = lib.mkForce null;
    options.mountpoint = lib.mkForce "legacy";
  };

  # Model B: the thin host exposes a share with tag "storage"; mount it.
  fileSystems."/storage" = {
    device = "storage";
    fsType = "virtiofs";
  };

  # Name the service-MAC NIC "eno1" (guest-hardware.nix pattern) so the
  # networking config keys off a stable name.
  systemd.network.links."10-eno1" = {
    matchConfig.MACAddress = "b8:ca:3a:6d:2d:24";
    linkConfig.Name = "eno1";
  };
  # NetworkManager (from overlay-boot-config) DHCPs it; the outer host's
  # dnsmasq reserves 10.99.0.9 for the service MAC.
}
