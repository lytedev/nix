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

  networking.hostName = lib.mkForce "mini-guest";

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
