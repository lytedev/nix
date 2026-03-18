# Google Photos to Immich

This is the recommended migration path for moving a Google Photos library into the existing Immich instance on `beefcake`, with a phased cutover.

## Defaults

- Host: `beefcake`
- External URL: `https://photos.lyte.dev`
- Immich data root: `/storage/immich`
- Staging root: `/storage/staging/google-photos-takeout`
- Import tool: `immich-go`
- Cutover: import first, validate for 1-2 weeks, then switch phones

## Deployed Setup

Immich is already wired into this repo and deployed with these defaults:

- service module: `packages/hosts/beefcake/immich.nix`
- host import: `packages/hosts/beefcake.nix`
- URL: `https://photos.lyte.dev`
- media root: `/storage/immich`
- backup coverage: `/storage/immich` is included in `services.restic.commonPaths`
- auth: Kanidm OIDC via `photos.lyte.dev`

The migration work here is about importing your Google Photos library into the existing service, not standing Immich up from scratch.

## 0. Preflight

Confirm the host has enough space for:

- the raw Google Takeout archives
- the extracted Takeout tree
- the Immich library itself
- thumbnails, transcodes, and backup growth

Quick checks:

```bash
ssh beefcake 'df -h /storage'
ssh beefcake 'du -sh /storage/immich 2>/dev/null || true'
```

Create the staging directories:

```bash
ssh beefcake 'mkdir -p \
  /storage/staging/google-photos-takeout/archives \
  /storage/staging/google-photos-takeout/extracted'
```

## 1. Export From Google Takeout

In `takeout.google.com`:

- export **Google Photos only**
- use `10 GB` to `50 GB` archive chunks
- leave the export in original quality
- download every archive before starting the import

Keep the downloaded Takeout files untouched. They are the rollback source.

## 2. Copy The Export To `beefcake`

If you downloaded locally, copy the archives to the staging area:

```bash
rsync -avh --progress /path/to/takeout/ beefcake:/storage/staging/google-photos-takeout/archives/
```

You can also drop them into the `daniel` Samba share and move them into `/storage/staging/...` on the server if that is more convenient.

## 3. Extract The Takeout Archives

On `beefcake`, extract every archive into the working tree. Keep the `.json` sidecars next to the media.

```bash
ssh beefcake '
  nix shell nixpkgs#unzip -c bash -lc "
    shopt -s nullglob
    cd /storage/staging/google-photos-takeout/archives
    for archive in *.zip; do
      unzip -n \"$archive\" -d /storage/staging/google-photos-takeout/extracted
    done
  "
'
```

Sanity check the extracted tree:

```bash
ssh beefcake 'find /storage/staging/google-photos-takeout/extracted -name "*.json" | wc -l'
ssh beefcake 'find /storage/staging/google-photos-takeout/extracted -type f | wc -l'
```

## 4. Create An Immich API Key

Create a fresh API key in the Immich UI for the migration.

`immich-go` currently expects a key with enough permissions to upload and manage related assets. If the import errors on permissions, recreate the key with broader asset permissions rather than reusing your day-to-day mobile key.

Recommended shell setup:

```bash
export IMMICH_SERVER='https://photos.lyte.dev'
export IMMICH_API_KEY='replace-me'
```

## 5. Pilot Import

Run a small dry run first, then a small real import. Start with one album or a narrow date range so you can verify timestamps and album behavior before committing to the full library.

Dry run:

```bash
ssh beefcake '
  export IMMICH_SERVER="'$IMMICH_SERVER'"
  export IMMICH_API_KEY="'$IMMICH_API_KEY'"
  nix shell nixpkgs#immich-go -c immich-go upload from-google-photos \
    --server "$IMMICH_SERVER" \
    --api-key "$IMMICH_API_KEY" \
    --dry-run \
    --log-file /tmp/immich-go-pilot.log \
    --from-album-name "Favorites" \
    /storage/staging/google-photos-takeout/extracted
'
```

Small real import:

```bash
ssh beefcake '
  export IMMICH_SERVER="'$IMMICH_SERVER'"
  export IMMICH_API_KEY="'$IMMICH_API_KEY'"
  nix shell nixpkgs#immich-go -c immich-go upload from-google-photos \
    --server "$IMMICH_SERVER" \
    --api-key "$IMMICH_API_KEY" \
    --log-file /tmp/immich-go-pilot.log \
    --from-album-name "Favorites" \
    /storage/staging/google-photos-takeout/extracted
'
```

If `Favorites` is not a good test album, swap in any small known album.

## 6. Validate The Pilot

Check the Immich UI before doing the full import:

- capture dates are correct on old photos
- albums are created sensibly
- edited photos and videos appear
- no obvious duplicate explosion
- background jobs complete cleanly

Do not delete duplicates yet.

## 7. Full Import

Once the pilot looks good, run the full import:

```bash
ssh beefcake '
  export IMMICH_SERVER="'$IMMICH_SERVER'"
  export IMMICH_API_KEY="'$IMMICH_API_KEY'"
  nix shell nixpkgs#immich-go -c immich-go upload from-google-photos \
    --server "$IMMICH_SERVER" \
    --api-key "$IMMICH_API_KEY" \
    --log-file /var/tmp/immich-go-full.log \
    /storage/staging/google-photos-takeout/extracted
'
```

Useful flags if needed:

- `--dry-run` to inspect behavior without uploading
- `--date-range` to import in chunks
- `--from-album-name` to test a single album
- `--include-unmatched` if some assets are missing JSON sidecars
- `--skip-verify-ssl` only if your TLS setup is not trusted locally

## 8. Validate Before Cutover

Leave Google Photos backup as-is during this period.

Check all of the following in Immich:

- rough photo/video totals are plausible
- old and recent years have correct capture dates
- a few important albums look right
- edited photos, live photos, and videos are present
- search and background processing behave normally

Keep this overlap for 1-2 weeks.

## 9. Backup Checkpoint

Before switching phones, confirm you have:

- the untouched Takeout export
- a backup of the Immich database
- a backup of `/storage/immich`

The current declarative integration points for Immich in this repo are:

- `packages/hosts/beefcake.nix`
- `packages/hosts/beefcake/restic.nix`
- `lib/modules/nixos/restic.nix`
- `packages/hosts/beefcake/caddy.nix`
- `packages/hosts/beefcake/postgres.nix`

## 10. Cut Over Phones

Switch one phone first.

- enable Immich auto backup
- keep it on Wi-Fi/charging-only if you want a gentle start
- confirm new photos land in Immich correctly
- watch for duplicates for a few days

Then switch the remaining phones.

Disable Google Photos auto-backup only after you are satisfied with:

- ongoing uploads
- server stability
- backup coverage

## Rollback

Until phone cutover is complete, rollback is simple:

- keep using Google Photos as normal
- keep the raw Takeout export unchanged
- if the import is bad, clear Immich and re-import with different flags

## Known Pitfalls

- wrong dates if sidecar metadata is ignored
- partial album recreation for some Google-only constructs
- duplicates from edits, shares, or prior manual uploads
- imperfect handling for some live/motion photos
