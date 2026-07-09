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
# Samba and anything added later without having to remember to lock it.
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
#   - 1883 MQTT (mosquitto, #584): LAN+tailnet only (NOT router-forwarded), but
#     the broker itself requires auth (allow_anonymous = false), so credentials
#     are the gate rather than source IP. Opened LAN-wide so dashboards and other
#     family clients (e.g. the pitft dashboard) can publish/subscribe without
#     per-device tailnet membership. Tailnet access is handled in mosquitto.nix.
# WHAT GETS LOCKED to dragon-only: everything else — notably Samba
#   (445/139/137/138 + WS-Discovery 5357/3702).
#
# IPv6: dragon's LAN IPv6 is SLAAC + privacy temp-addresses (unstable), so we
# CAN'T reliably allowlist dragon by v6 source IP the way the v4 chain does —
# a v6 default-deny would lock dragon out of everything too. So instead of
# mirroring the v4 default-deny, the v6 side is a targeted DENYLIST gated by
# interface: on the LAN interface (${lan}) we DROP inbound v6 to just the
# sensitive Samba + WS-Discovery ports, and leave every other v6 flow alone.
#   - Samba/WS-Discovery isn't router-forwarded and the router does no v6 NAT,
#     so these ports have no legitimate off-LAN or public v6 caller — the only
#     thing this blocks is LAN-local v6 clients reaching them, which is exactly
#     the hole M4-ipv6 flagged (SLAAC is on, so v6 was an open bypass).
#   - dragon doesn't lose anything: it reaches Samba over v4 (allowlisted by
#     src IP above) and over the tailnet, not LAN-v6, so dropping LAN-v6 Samba
#     is safe for it.
#   - Only the ${lan} interface is matched, so tailscale0 (Samba over the
#     tailnet, intentional per Daniel) and loopback are untouched.
#   - ICMPv6/NDP is NOT touched (we only match the sensitive L4 ports), so
#     SLAAC/RA/neighbor-discovery keep working — v6 stays healthy.
# The guest-VLAN L2 isolation staged on the router is still the real long-term
# fix (it walls off both protocols at L2 for casual clients); this v6 denylist
# is the interim that brings v6 up to the v4 intent for the sensitive ports.
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
  # Sensitive ports the LAN default-deny locks to dragon-only over v4. Over v6
  # we can't identify dragon (SLAAC), so we DROP these outright on the LAN
  # interface — see the IPv6 note in the header for why that's safe. Samba
  # (SMB 445, NetBIOS session 139) + WS-Discovery (5357).
  sensitiveV6Tcp = "139,445,5357";
  # NetBIOS name/datagram (137/138) + WS-Discovery multicast (3702).
  sensitiveV6Udp = "137,138,3702";
  # Internet-public (router DNAT-forwarded) + LAN-infra ports — open to all.
  # Keep in sync with the router's beefcake `nat` block (packages/hosts/router.nix).
  publicTcp = "22,25,80,443,465,587,993,8080,24454,26968,26969,26974,26989";
  publicUdp = "3478,5353,10001,24454,26974,26989,34197";
  # Auth-gated services intentionally reachable by any LAN client. Unlike
  # publicTcp these are NOT router-forwarded / internet-public — they're
  # LAN+tailnet only, and the service itself requires credentials, so the
  # password is the gate rather than source IP.
  #   1883: mosquitto MQTT broker (#584), allow_anonymous = false.
  authGatedLanTcp = "1883";
  # Music Assistant audio DATA plane. Cast/AirPlay/squeezelite players stream the
  # audio MA itself serves from :8097, squeezelite's SlimProto control is on
  # :3483, and the MA Companion App's native Sendspin player connects directly to
  # :8927. Unlike the rest of beefcake's services these CAN'T move to the tailnet:
  # the players are consumer LAN devices (Nest speakers, kids' tablets, the
  # steamdeck) that can't be tailnet peers, and MA serves every player from one
  # publish-IP, so the stream has to be LAN-reachable. MA's admin/API (:8095)
  # deliberately stays OFF this list — it's reached only via the Caddy TLS vhost
  # (music-assistant.h.lyte.dev). Not auth-gated, so it's open LAN-wide like
  # publicTcp rather than password-gated like MQTT.
  lanMediaTcp = "3483,8097,8927";
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
    # Auth-gated LAN services (MQTT): broker requires credentials, so opening the
    # port LAN-wide is gated by auth, not source IP. See authGatedLanTcp above.
    iptables -A nixos-lan-lockdown -p tcp -m multiport --dports ${authGatedLanTcp} -j RETURN
    # Music Assistant audio data plane (Cast/AirPlay/squeezelite); see lanMediaTcp.
    iptables -A nixos-lan-lockdown -p tcp -m multiport --dports ${lanMediaTcp} -j RETURN
    # DNS secondaries (1984/he) -> beefcake:53 (AXFR/SOA); beefcake = lyte.dev primary.
    ${dnsCarveRules}
    iptables -A nixos-lan-lockdown -j DROP
    # Hook NEW inbound connections arriving on the LAN into the lockdown chain.
    # Matching ctstate NEW means it sits harmlessly above the firewall's
    # established/related accept (established traffic never enters the chain),
    # and RETURN lets allowed packets fall through to normal accept rules.
    iptables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown 2>/dev/null || true
    iptables -I nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown

    # --- IPv6 (M4-ipv6): targeted denylist, NOT default-deny. See the header.
    # We can't allowlist dragon over SLAAC v6, so instead of a v4-style default
    # -deny (which would break dragon's v6), we DROP only the sensitive Samba +
    # WS-Discovery ports arriving on the LAN interface. Everything else v6 falls
    # through this chain untouched (no trailing DROP), so ICMPv6/NDP and all
    # other services keep working. tailscale0 is never matched (we bind to
    # ${lan}), so Samba over the tailnet is unaffected.
    ip6tables -N nixos-lan-lockdown6 2>/dev/null || ip6tables -F nixos-lan-lockdown6
    ip6tables -A nixos-lan-lockdown6 -p tcp -m multiport --dports ${sensitiveV6Tcp} -j DROP
    ip6tables -A nixos-lan-lockdown6 -p udp -m multiport --dports ${sensitiveV6Udp} -j DROP
    ip6tables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown6 2>/dev/null || true
    ip6tables -I nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown6
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown 2>/dev/null || true
    iptables -F nixos-lan-lockdown 2>/dev/null || true
    iptables -X nixos-lan-lockdown 2>/dev/null || true

    ip6tables -D nixos-fw -i ${lan} -m conntrack --ctstate NEW -j nixos-lan-lockdown6 2>/dev/null || true
    ip6tables -F nixos-lan-lockdown6 2>/dev/null || true
    ip6tables -X nixos-lan-lockdown6 2>/dev/null || true
  '';
}
