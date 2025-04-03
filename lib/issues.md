- [ ] forgejo slow
  - might be resolved with anubis
  - still seems like runners hitting the server causes CPU to hover around 50% (of one thread)
- [ ] single identity provider
  - I have at least some setup for kanidm, but not sure it has the interface for what I need, though I think declarative config for kanidm has been merged and may serve perfectly
    - would I use this just for internal/in-home services? vaultwarden? jellyfin? forgejo? etc.?
    - would I (could I/should I) use the same instance for external stuff?
  - also recommended:
    - authelia
    - authentik (has some recent CVEs? sign of bad code or of good white hats?)
    - zitadel
    - keycloak
    - ory
  - though I definitely want to avoid anything JVM-related due to my own inexperience and negative predispositions, which I believe excludes keycloak
- [ ] nix-on-droid?
- [ ] update to GNOME 48
  - nixpkgs pr: https://github.com/NixOS/nixpkgs/pull/386514
  - release notes: https://release.gnome.org/48/
- [ ] tailscale dependence?
  - I think some machines (dragon) are only accessible via tailscale ssh?
    I want to either:
    - ensure LAN ssh access
    - ensure a self-hosted VPN is also an option
    I want to avoid Tailscale as a single point of failure
- [ ] base OS is huge
  I think it's >20GB, citation needed
  Wanna know how to shrink it
  this also causes really annoying problems deploying the rascal host which only has a 16GB disk - it can barely hold two generations at once
- [ ] nix-darwin for work
  determinate nix should make this relatively straightforward
  not sure how it will play with the corporate controlware
- [ ] pull in site.lyte.dev to this monorepo
  why?
- [ ] fully automated/declarative github mirroring
  right now I think the key expires every so often and I'm not sure I have a way to know when I fall behind? perhaps a very simple val.town script could suffice?
- [ ] ghostty long command finishes only notify when not focused
  link: https://github.com/ghostty-org/ghostty/discussions/3555
- [ ] automated backups verification job
  not sure how to manage this securely per se unless it happens on the desktop which is almost always on and tries verifying backups daily
  - if we go a day or two without a backup verification, fire an alert
  - if we definitely fail a backup verification, fire an alert
  backups should be verified from all three sources:
  - local
  - two remote backup locations


