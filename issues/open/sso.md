# SSO

**Labels**: service, beefcake
**Related**: packages/hosts/beefcake/kanidm-migrations/20-oauth2.hjson

Kanidm is deployed at `idm.h.lyte.dev` with declarative HJSON migrations and
a `kanidm-oauth2-secrets` module for automatic secret fetching.

## Integrated

- Immich (photos.lyte.dev)
- Headscale (vpn.h.lyte.dev)
- Tuwunel/Matrix (matrix.lyte.dev)
- Bulwark/Stalwart webmail (webmail.lyte.dev)
- Forgejo (git.lyte.dev) — OAuth2 client configured in migrations

## Not yet integrated

- Jellyfin (video.lyte.dev)
- Audiobookshelf (audio.lyte.dev)
- Nextcloud
- Vaultwarden
- Samba shares

## Kanidm Alternatives

Just in case:

- Authelia
- authentik
- ZITADEL
- Keycloak (JVM — prefer to avoid)
- Ory
