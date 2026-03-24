# Self-hosted authoritative DNS

**Labels**: infrastructure, dns, pebble

Replace Netlify DNS with self-hosted authoritative nameservers for full
control over zone data. Motivated by a ghost MX record stuck in Netlify's
nsone backend that doesn't appear in the API and can't be deleted.

## Recommended approach

**NSD as hidden primary on pebble + free secondary DNS services**

- NSD has the best NixOS module (`services.nsd`) with declarative zone config
- Use [dns.nix](https://github.com/nix-community/dns.nix) for Nix DSL zone definitions
- Free secondaries provide HA and geographic distribution:
  - 1984 Hosting (ns0-2.1984.is) — Icelandic, anycast, free
  - Hurricane Electric (ns1-5.he.net) — global anycast, free
- Pebble serves AXFR to secondaries only (hidden primary pattern)
- Registrar NS records point to 1984 + HE, not pebble directly
- If pebble goes down, secondaries keep serving (SOA expire = days)

## Architecture

```
pebble (hidden primary, NSD, not in NS records)
  ├── AXFR/NOTIFY → 1984 Hosting (ns0.1984.is, ns1.1984.is, ns2.1984.is)
  └── AXFR/NOTIFY → Hurricane Electric (ns1-5.he.net)

Registrar NS records → 1984 + HE nameservers only
Zones defined declaratively in Nix via dns.nix
```

## Why NSD over alternatives

- **vs Knot DNS**: NSD has better NixOS module (zones in Nix config directly).
  Knot wins on automated DNSSEC but NSD's `dnssec-keymgr` integration is adequate.
- **vs PowerDNS**: NSD is simpler (no database). PowerDNS only makes sense if
  you need a REST API for dynamic record management.
- **vs BIND**: No reason to choose BIND in 2025+. Slower, heavier, more CVEs.

## Tasks

- [ ] Add dns.nix flake input
- [ ] Define lyte.dev zone declaratively in Nix (migrate all current records)
- [ ] Configure NSD on pebble with AXFR + TSIG for secondaries
- [ ] Sign up for 1984 Hosting and/or Hurricane Electric free secondary DNS
- [ ] Set up TSIG keys for zone transfers
- [ ] Enable DNSSEC signing
- [ ] Update registrar NS records to point to secondaries
- [ ] Verify resolution from all public resolvers
- [ ] Remove Netlify DNS zone (danger zone — only after everything works)
- [ ] Remove DDNS service dependency for static records (MX, TXT, etc.)

## Related

- `packages/hosts/pebble.nix` — mail VPS where NSD would run
- `packages/services/netlify-ddns/` — current DDNS service (partially replaced)
- `lib/doc/email-architecture.md` — mail setup context
- Ghost MX record: `mxa.mailgun.org` visible in DNS but not in Netlify API
