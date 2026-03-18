# Email Architecture: lyte.dev

## Phase 1: Simple (current target)

Beefcake runs the full Stalwart stack. A cheap VPS acts as a dumb SMTP
relay to solve residential IP / port 25 / PTR problems. If beefcake is
down, the VPS queues mail (standard SMTP retry) but new mail is not
readable until beefcake comes back.

```
Inbound:   Internet --> MX --> VPS (Postfix relay) --> Tailscale --> beefcake (Stalwart)
Outbound:  beefcake (Stalwart) --> Mailgun (port 587)
IMAP:      clients --> beefcake (port 993 via Caddy/Tailscale)
CalDAV:    clients --> beefcake (HTTPS)
Webmail:   browser --> beefcake (HTTPS, Stalwart built-in)
SSO:       Kanidm OIDC on beefcake (webmail), app passwords (IMAP clients)

Beefcake down:
  - VPS accepts and queues inbound (retries for 1-5 days)
  - IMAP clients have cached copies of all mail up to the outage
  - Outbound still works if using Mailgun directly from a phone/laptop
  - When beefcake returns, VPS flushes queue, no mail lost
```

### VPS config (minimal)

- Postfix relay-only (no local delivery, no mailboxes)
- Accepts on port 25, relays to beefcake over Tailscale
- Stateless and disposable (~$4/mo)
- `host-mail` Kanidm service account (for future use)

### Beefcake config

- Stalwart: SMTP, IMAP, JMAP, CalDAV, CardDAV, webmail
- Kanidm OIDC for webmail SSO
- RocksDB local storage
- Restic backup of mail data
- Mailgun for outbound (port 587, works from residential)

### DNS

- `mail.lyte.dev` A/AAAA --> VPS IP (static)
- `lyte.dev` MX 10 --> `mail.lyte.dev`
- SPF: `v=spf1 include:mailgun.org a:mail.lyte.dev ~all`
- DKIM: Stalwart-generated key published as TXT
- DMARC: `v=DMARC1; p=quarantine; rua=mailto:postmaster@lyte.dev`

---

## Phase 2: Dream Mode (HA with hot standby)

Beefcake remains the primary mail server. The VPS runs a full Stalwart
instance that automatically activates when beefcake is unreachable.
Phones and clients continue receiving mail during beefcake downtime.

```
Normal operation (beefcake up):
  Inbound:   Internet --> MX --> VPS (Stalwart) --> relay to beefcake (Stalwart)
  IMAP:      clients --> mail.lyte.dev --> beefcake
  Outbound:  beefcake --> Mailgun
  CalDAV:    clients --> beefcake

Failover (beefcake down, automatic):
  Inbound:   Internet --> MX --> VPS (Stalwart, delivers locally)
  IMAP:      clients --> mail.lyte.dev --> VPS (serves from local store)
  Outbound:  VPS --> Mailgun
  CalDAV:    VPS (serves from local store)

Recovery (beefcake back, automatic):
  VPS syncs accumulated mail --> beefcake (imapsync/JMAP)
  DNS floats back to beefcake
  VPS resumes relay-only mode
```

### How failover works

1. A health check (systemd timer or Tailscale status) on the VPS
   monitors beefcake's reachability.

2. Normal mode: VPS Stalwart is configured with beefcake as the
   `next-hop` for all inbound mail. Mail arrives, gets relayed
   immediately, VPS stores nothing.

3. Failover mode: When beefcake is unreachable, the VPS switches to
   local delivery. Stalwart accepts mail into its own RocksDB store
   and serves IMAP/CalDAV/webmail directly.

4. Recovery: When beefcake comes back, a sync job runs:
   - `imapsync` from VPS --> beefcake (push all mail that accumulated)
   - Or JMAP sync if Stalwart supports server-to-server sync by then
   - After sync completes, VPS clears its local store
   - VPS switches back to relay mode

### DNS failover for clients

Option A: Health-checked DNS
- Use Cloudflare or a custom DDNS health check
- `mail.lyte.dev` normally resolves to beefcake
- On health check failure, resolves to VPS
- Clients transparently reconnect

Option B: Dual-server client config
- `imap.lyte.dev` --> beefcake (primary)
- `imap-fallback.lyte.dev` --> VPS
- Users manually switch, or use a mail client that supports failover

Option C: SRV records with priorities
- SRV `_imaps._tcp.lyte.dev` priority 10 --> beefcake, priority 20 --> VPS
- Supported by some clients (Thunderbird via autoconfig)

### Sync mechanism options

Option A: imapsync cron (simplest)
- VPS runs `imapsync --host1 localhost --host2 beefcake.internal.vpn.h.lyte.dev`
- Triggered when beefcake becomes reachable again
- One-directional: VPS --> beefcake
- Handles mail, not calendar/contacts

Option B: JMAP replication (if Stalwart adds support)
- Native server-to-server sync
- Handles mail + calendar + contacts
- Not available as of 2026, but on Stalwart's roadmap

Option C: dsync / doveadm-style sync
- Stalwart doesn't support this natively
- Would require an external tool

### What's needed beyond Phase 1

1. Stalwart on the VPS (upgrade from Postfix relay-only)
2. Health check service on VPS monitoring beefcake
3. Mode-switching script (relay mode <-> local delivery mode)
4. Sync job for recovery
5. DNS failover mechanism
6. CalDAV/CardDAV sync (imapsync only handles mail)
7. Shared Kanidm auth (both servers authenticate against beefcake's
   Kanidm -- VPS uses OIDC over Tailscale)

### Estimated additional complexity

- VPS goes from ~50 lines of Postfix config to a full Stalwart instance
- Health check + mode switching: ~100 lines of systemd/bash
- Sync job: ~50 lines (imapsync wrapper)
- DNS failover: depends on approach (Cloudflare API, custom DDNS check)
- Calendar sync: unsolved without JMAP replication

### When to implement

Phase 2 makes sense when:
- Beefcake has extended downtime (hardware upgrades, moves, etc.)
- Email volume increases and delivery delays are unacceptable
- Stalwart adds native replication (simplifies sync dramatically)
- You want to offer email to more users (friends, family beyond core)
