# Interim LAN hardening: lock beefcake's sensitive services to the dragon
# bastion over the wired/wireless LAN.
#
# WHY: WiFi clients currently share the untagged LAN with wired gear (the
# proper isolated guest VLAN is staged on the router but needs a UniFi SSID
# tag, pending controller creds). beefcake opens several sensitive services
# on ALL interfaces — Samba shares, the *arr stack, and the k3s API. Until
# the VLAN lands, a guest on the main WiFi could reach those. This restricts
# them, *on the LAN interface only*, to dragon (the LAN admin/bastion box).
#
# DESIGN (per Daniel): tailnet (headscale) is the primary admin path and is
# left fully open — these rules only touch the `${lan}` interface, never
# tailscale0 — so this does not affect tailnet access at all. dragon
# (192.168.0.10, MAC-reserved) is the single LAN *fallback* path: you hop
# through dragon for direct LAN admin when the tailnet is down. Public web
# (80/443, SSO-gated), mail, SSH, and game-server ports stay open on the LAN.
#
# IPv4 ONLY: dragon's LAN IPv4 is pinned but its IPv6 is SLAAC (unstable), so
# locking v6 risks breaking dragon via happy-eyeballs. We leave v6 open here;
# the residual gap (a guest reaching a service over IPv6) is closed properly
# by the guest VLAN, which isolates at L2 for both protocols. Samba discovery
# is v4/mDNS, so the casual-guest hole is closed by the v4 lock.
#
# Reversible: pure firewall extraCommands; remove this import + redeploy (or
# `iptables -F nixos-fw` / reboot) to revert.
{ ... }:
let
  lan = "eno1"; # beefcake's wired LAN interface (see unifi.nix)
  dragon = "192.168.0.10"; # bastion; MAC-reserved on the router
  # samba (445/139), *arr (9876/9877), k3s api+kubelet (6443/10250)
  tcpPorts = "445,139,9876,9877,6443,10250";
  # netbios (137/138), *arr udp (9876/9877)
  udpPorts = "137,138,9876,9877";
  rules = proto: ports: ''
    iptables -I nixos-fw -i ${lan} ! -s ${dragon} -p ${proto} -m multiport --dports ${ports} -j DROP
  '';
  delRules = proto: ports: ''
    iptables -D nixos-fw -i ${lan} ! -s ${dragon} -p ${proto} -m multiport --dports ${ports} -j DROP 2>/dev/null || true
  '';
in
{
  # Inserted at the top of nixos-fw, but each rule is narrowly scoped (LAN
  # iface + specific dports + not-from-dragon), so non-matching traffic
  # (other ports, dragon, established connections on other ports) falls
  # straight through to normal firewall processing.
  networking.firewall.extraCommands = (rules "tcp" tcpPorts) + (rules "udp" udpPorts);
  networking.firewall.extraStopCommands = (delRules "tcp" tcpPorts) + (delRules "udp" udpPorts);
}
