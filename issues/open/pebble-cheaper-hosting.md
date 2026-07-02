# Explore cheaper hosting for pebble (someday)

**Labels**: cost, infra, someday
**Related**: `packages/hosts/pebble.nix`, `packages/hosts/pebble/ntfy.nix`, `lib/doc/alerting.md`

pebble is a Hetzner **CX23** (2 vCPU / 4 GB / 40 GB, Helsinki HEL1), currently on a
**grandfathered $4.99/mo** rate. It BARELY does anything — it exists mostly to hold a
**static IPv4** and run three light services:

- knot (secondary authoritative DNS for lyte.dev)
- mail front (HAProxy + Postfix relay → beefcake Stalwart; MX target)
- ntfy + Caddy (off-site push for the Tier 0 uptime watcher)

Real resource use is ~555 MB RAM. The 4 GB / 2 vCPU is massive overkill; **what we're
actually paying for is the static IPv4 + unblocked port 25 + KVM**, not compute.

## Goal

Someday, cut this expense without losing: a routable **static IPv4**, **usable port 25**
(inbound+outbound SMTP, for the MX/relay), and **KVM** (so NixOS installs). Compute/RAM
are irrelevant — a 1 GB box is plenty.

## Research done 2026-07-01 (verdict: STAY for now)

The three requirements together — static v4 + port 25 + KVM — are the price floor, not RAM.
Findings:

| Option | All-in $/mo | Port 25 | Notes |
|---|---|---|---|
| **Stay: grandfathered Hetzner** | **$4.99** | works (already warmed) | A *new* Hetzner CX23 = €5.49 + €0.50 IPv4 ≈ **$6.60**, and new accounts wait ~1mo for port 25. Our rate is a good legacy deal; **rescaling reprices upward**. |
| **Netcup** VPS nano | ~$3.55 | **self-serve unblock, no ticket** | Best migration target: established DE host, IPv4 incl, custom-ISO for NixOS. Small one-time setup fee on cheapest tier. |
| **BuyVM / FranTech** Slice 1024 | $3.50 | unblock via ticket | Most mail-honest + rock-solid rep; 1 GB slices often out of stock. |
| **RackNerd** 1 GB | $1.83 ($22/yr) | open by default | Cheapest that works, but "open in practice not ToS", aggressive abuse null-routing, shared IPs often pre-blacklisted → must vet the assigned IP. |

**Disqualified:** Oracle Free (port 25 permanently blocked outbound), Vultr/Linode (25
blocked, ticket "not guaranteed"), Scaleway (IPv4 now +€3.65 → ~$11 all-in), Contabo
(shared-IP mail-reputation hazard), 1984 Hosting (mail-friendly but ~$9.66).

**Price floor:** ~$1.80–2.10/mo (LowEnd, you babysit the IP) · ~$3.50/mo (Netcup/BuyVM,
reliable) · ~$4.5–7/mo (SLA-backed OVH/Hetzner).

## Why not now

Savings are only ~$1.50–3/mo (~$18–36/yr). pebble is **load-bearing DNS + MX**, so a
migration means re-warming a new IPv4's reputation and redoing PTR/SPF/DKIM/DMARC +
clearing RBLs — the IP-reputation step (not the port-25 toggle) is the real deliverability
risk. Not worth it for a couple dollars right now.

## If/when we revisit

- **Netcup ~$3.50** is the cleanest target (self-serve port 25).
- Or rethink the topology: does the static-IP/mail role *have* to be its own VPS, or could
  the MX move (e.g. a managed inbound relay / different secondary-DNS arrangement) so pebble
  can shrink to an IPv6-mostly or even-cheaper box? That reframing could beat the price floor
  that "static v4 + port 25 + KVM" otherwise imposes.
