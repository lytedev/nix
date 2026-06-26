# Interim LAN hardening: default-deny everything from the LAN to beefcake,
# except dragon (the admin/bastion box) and an explicit allowlist of ports
# that are either internet-public (DNAT-forwarded by the router) or required
# by LAN infrastructure (UniFi APs, mDNS).
#
# WHY: WiFi clients currently share the untagged LAN with wired gear (the
# isolated guest VLAN is staged on the router but needs a UniFi SSID tag,
# pending controller creds). Rather than chase a denylist of sensitive ports,
# we flip to default-deny so that *every* service — current and future — is
# closed to non-dragon LAN clients unless explicitly opened. This protects
# Samba, MQTT, and anything added later without having to remember to lock it.
#
# DESIGN (per Daniel): the tailnet (headscale) is the primary admin path and
# is left fully open — these rules only match the `${lan}` interface, never
# tailscale0. dragon (192.168.0.10, MAC-reserved) is the single LAN *fallback*
# and gets unrestricted access. "Only tailnet stuff" for everyone else: other
# LAN devices reach beefcake's services over the tailnet, not direct LAN ports.
#
# WHAT STAYS OPEN to the whole LAN (and why it's safe / necessary):
#   - 22/25/80/443/465/587/993 + game ports: DNAT-forwarded from the WAN, so
#     they're already internet-public; a LAN guest is no worse than any
#     internet host (web is SSO-gated, mail/SSH need creds). Blocking them on
#     eno1 would break the router's port-forwards.
#   - 8080 + udp/10001: UniFi AP inform/discovery — APs live on the LAN.
#   - udp/5353 mDNS, udp/3478 STUN: discovery / NAT traversal.
# WHAT GETS LOCKED to dragon-only: everything else — notably Samba
#   (445/139/137/138 + WS-Discovery 5357/3702) and MQTT 1883 (mosquitto;
#   auth-gated and meshtasticd is currently disabled — when it's re-enabled,
#   add the gateway's IP here or put it on the trusted VLAN).
#
# IPv4 ONLY: dragon's LAN IPv6 is SLAAC (unstable) so we can't reliably
# allowlist it; locking v6 risks breaking dragon via happy-eyeballs. v6 is
# left open here — the guest VLAN is the real fix and isolates both protocols
# at L2. (Samba/MQTT discovery from casual clients is v4, so the practical
# hole is closed.)
#
# IMPORTANT: this is a hand-maintained allowlist. If you add a new
# internet-forwarded service on the router, add its port here too or LAN
# clients (and the forward) will be blocked from it.
#
# Reversible: pure firewall extraCommands; remove the import + redeploy.
{ ... }:
let
  lan = "eno1"; # beefcake's wired LAN interface (see unifi.nix)
  dragon = "192.168.0.10"; # admin/bastion; MAC-reserved on the router
  # Internet-public (router DNAT-forwarded) + LAN-infra ports — open to all.
  # Keep in sync with the router's beefcake `nat` block (packages/hosts/router.nix).
  publicTcp = "22,25,80,443,465,587,993,8080,24454,26968,26969,26974,26989";
  publicUdp = "3478,5353,10001,24454,26974,26989,34197";
  # beefcake is the active hidden DNS primary for lyte.dev (see ./dns-primary.nix),
  # so the 1984.is + he.net secondaries pull the zone via AXFR. Those connections
  # hit the home WAN IP, are DNAT'd by the router to beefcake:53, and arrive on
  # eno1 from these source IPs with ctstate NEW — they must bypass the default-deny.
  # Source-restricted (the router forwards :53 broadly; this allowlist is the real
  # gate). Permanent — pebble (the warm-standby secondary) pulls over the tailnet,
  # which isn't subject to this LAN lockdown, so it's not in this list.
  dnsSecondaries = [
    "45.76.37.222" # ns0.1984.is
    "194.58.192.36" # ns1.1984.is
    "45.32.180.186" # ns2.1984.is
    "93.95.226.52" # ns2.1984.is (secondary)
    "185.42.137.114" # ns1.1984hosting.com
    "93.95.226.53" # ns2.1984hosting.com
    "93.95.224.6" # 1984 transfer server
    "216.218.130.2" # ns1.he.net
    "216.218.131.2" # ns2.he.net
    "216.218.132.2" # ns3.he.net
    "216.66.1.2" # ns4.he.net
    "216.66.80.18" # ns5.he.net
  ];
  dnsCarveRules = builtins.concatStringsSep "\n    " (
    builtins.concatMap (ip: [
      "iptables -A nixos-lan-lockdown -s ${ip} -p tcp --dport 53 -j RETURN"
      "iptables -A nixos-lan-lockdown -s ${ip} -p udp --dport 53 -j RETURN"
    ]) dnsSecondaries
  );
in
{
  networking.firewall.extraCommands = ''
    # beefcake LAN default-deny (see lan-lockdown.nix). Dedicated chain so the
    # policy is self-contained and easy to reason about.
    iptables -N nixos-lan-lockdown 2>/dev/null || iptables -F nixos-lan-lockdown
    iptables -A nixos-lan-lockdown -s ${dragon} -j RETURN
    iptables -A nixos-lan-lockdown -p icmp -j RETURN
    iptables -A nixos-lan-lockdown -p tcp -m multiport --dports ${publicTcp} -j RETURN
    iptables -A nixos-lan-lockdown -p udp -m multiport --dports ${publicUdp} -j RETURN
    # DNS secondaries (1984/he) -> beefcake:53 (AXFR/SOA); beefcake = lyte.dev primary.
    ${dnsCarveRules}
    iptables -A nixos-lan-lockdown -j DROP
    # Hook NEW inbound connections arriving on the LAN into the lockdown chain.
    # Matching ctstate NEW means it sits harmlessly above the firewall's
    # established/related accept (established traffic never enters the chain),
    # and RETURN lets allowed packets fall through to normal accept rules.
    iptables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown 2>/dev/null || true
    iptables -I nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown 2>/dev/null || true
    iptables -F nixos-lan-lockdown 2>/dev/null || true
    iptables -X nixos-lan-lockdown 2>/dev/null || true
  '';
}
