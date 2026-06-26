# Miyoo Mini Plus ROM Sync configuration
# Edit this to match your server's LAN address.
#
# Prefer the hostname over a hardcoded IP: `beefcake.lan` resolves via the
# router's dnsmasq, so it decouples from beefcake's DHCP-reserved LAN IP. (It
# briefly stopped resolving for LAN clients due to a :53 hairpin-DNAT bug, since
# fixed in the router config.) If you change this, also update the matching
# host-key entry in .ssh/known_hosts.
SYNC_HOST="beefcake.lan"

# Set to 1 to also sync save states (can be large).
SYNC_STATES=1
