# SSO

**Labels**: service, beefcake

I would love for Jellyfin, Audiobookshelf, Samba shares, etc. to all use a single
authentication/authorization mechanism for the whole family.

Kanidm is fully setup, but not integrated with anything.

Perhaps the SpacetimeDB instance would be a good starting point? Just need JWTs?

Kanidm 1.9 introduces native HJSON-based entry migrations (`migration_path`),
replacing the broken NixOS provision module and the need for oddlama/kanidm-provision.
A custom `kanidm-migrations` NixOS module generates the migration files from Nix config.

## Kanidm Alternatives

Currently, I'm too ignorant to pretend to know why I might want to swap, but
just in case:

- Authelia
- authentik (has some recent CVEs? sign of bad code or of good white hats?)
- ZITADEL
- Keycloak
- Ory

I definitely want to avoid anything JVM-related due to my own inexperience and
negative predispositions, which I believe excludes keycloak
