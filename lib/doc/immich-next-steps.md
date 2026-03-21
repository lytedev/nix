# Immich Next Steps

Immich is deployed on `beefcake`, Kanidm mobile OAuth is working, and the mobile app can log in successfully. The remaining work is operational: import your Google Photos library, validate the result, then cut over mobile backup carefully.

## Current State

- URL: `https://photos.lyte.dev`
- Host: `beefcake`
- Media root: `/storage/immich`
- Auth: Kanidm OIDC, including mobile redirect support
- Backup coverage: `/storage/immich` is included in restic

## Recommended Next Steps

### 1. Run A Small Google Photos Pilot Import

- export a small Google Takeout subset first
- stage it on `beefcake` under `/storage/staging/google-photos-takeout`
- import it with `immich-go`
- validate timestamps, albums, videos, edits, and duplicates before doing the full library

See `./lib/doc/immich-google-photos-migration.md` for the full command sequence.

### 2. Create A Dedicated Migration API Key

- create a fresh API key in Immich specifically for the migration
- do not reuse your day-to-day mobile key
- keep the key around until the full import and validation are complete

### 3. Validate Before Full Cutover

- compare rough photo/video totals with Google Photos
- spot-check old and recent years for correct capture dates
- check a few important albums and edited items
- let Immich background jobs finish before judging the final result

### 4. Cut Over Phones Gradually

- enable Immich auto backup on one phone first
- confirm new uploads behave correctly
- watch for duplicate behavior for a few days
- then enable Immich on the rest of the phones
- disable Google Photos backup only after you trust the new flow

### 5. Keep The Manual Kanidm OAuth Note In Mind

The Kanidm-side mobile redirect URLs are currently present live, but one part is still not fully declarative:

- `app.immich:///oauth-callback` cannot currently be represented in the HJSON migration path without Kanidm rejecting it
- the repo documents this in `packages/hosts/beefcake/kanidm-migrations/20-oauth2.hjson`
- if Kanidm fixes multivalue/opaque `oauth2_rs_origin` handling in migrations later, this can be moved back into config management cleanly

## If You Want To Continue Right Now

The practical order is:

1. create an Immich migration API key
2. export a small Google Takeout subset
3. copy it to `beefcake`
4. run the pilot `immich-go` import
5. validate the result in the app and web UI
6. then do the full import
