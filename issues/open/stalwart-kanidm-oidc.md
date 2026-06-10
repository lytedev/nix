# Stalwart ↔ Kanidm OIDC integration (bulwark webmail SSO)

**Labels**: mail, stalwart, kanidm, sso
**Related**: issues/open/stalwart-0.16-upgrade.md

**Status**: DRAFT — config landed, **needs sandbox verification before merge/deploy**.

## Goal

Bulwark webmail (`webmail.lyte.dev`) authenticates against **Kanidm**
(`idm.h.lyte.dev`) instead of stalwart's internal OAuth, so mail SSO uses the
same identity provider as everything else. Stalwart 0.16 accepts the
Kanidm-issued tokens via an additive `Oidc` Directory.

## Design

Three pieces, all declarative:

1. **Kanidm OAuth2 client** (`packages/hosts/beefcake/kanidm-migrations/20-oauth2.hjson`)
   - `bulwark-webmail`, **public client** (`oauth2_resource_server_public`)
     with PKCE — bulwark is a browser SPA doing the authorization-code flow,
     so there is no confidential client secret to manage (no
     `kanidm-oauth2-secrets` entry needed).
   - Redirect URI: `https://webmail.lyte.dev/api/auth/callback` (strict).
   - `oauth2_prefer_short_username = true` so `preferred_username` is
     `daniel`, not the SPN `daniel@idm.h.lyte.dev`.
   - Access gated by new group `bulwark-webmail_users` (00-groups.hjson).

2. **Stalwart Oidc directory** (`packages/hosts/beefcake/stalwart.nix` plan)
   - `Directory` op, destroy-all + create (owned-type idempotency pattern):

     ```nix
     value.kanidm = {
       "@type" = "Oidc";
       issuerUrl = "https://idm.h.lyte.dev/oauth2/openid/bulwark-webmail";
       claimUsername = "preferred_username";
       claimName = "name";
       usernameDomain = "lyte.dev";
       requireAudience = "bulwark-webmail";
     };
     ```

   - `issuerUrl` is the Kanidm per-client issuer; stalwart auto-discovers
     endpoints from it.
   - `usernameDomain` is appended when the claim lacks `@`:
     `daniel` → `daniel@lyte.dev` → maps to the existing internal account.
   - `requireAudience` rejects tokens minted for other Kanidm clients.

3. **Bulwark env** (`packages/hosts/beefcake/bulwark.nix`)
   - `OAUTH_ISSUER_URL` → the Kanidm issuer (was `https://mail.lyte.dev`).
   - `OAUTH_CLIENT_ID` stays `bulwark-webmail` (same id on the Kanidm side).
   - `OAUTH_ALLOW_PRIVATE_ENDPOINTS=true` kept — split-horizon DNS resolves
     `idm.h.lyte.dev` to a private address inside the container too.
   - `JMAP_SERVER_URL` still points at stalwart; only auth moves to Kanidm.

The stalwart-internal `OAuthClient` `bulwark-webmail` is kept for now as a
fallback; remove it in a follow-up once the Kanidm path is verified.

## Caveats / known unknowns (do NOT merge until addressed)

1. **Password auth must keep working.** Thunderbird-style IMAP/SMTP
   `AUTH PLAIN` cannot go through Kanidm (no ROPC support), so the internal
   directory's accounts/passwords stay authoritative — the Oidc directory is
   strictly additive. **Unverified:** how stalwart 0.16's `Authentication`
   singleton arbitrates between the internal directory and an additional
   Oidc directory (fallback order? does creating an Oidc directory change
   the default auth directory?). Must be confirmed in a sandbox.
2. **Destroy-all `Directory` assumption.** The plan uses the owned-type
   `destroy {} + create` pattern. This assumes the *internal* directory is
   implicit (not a `Directory` object that destroy-all would delete).
   Verify on the sandbox that destroy-all does not nuke internal auth.
3. **Token validation latency/caching.** Stalwart calls Kanidm's userinfo
   endpoint to validate each bearer token; whether/how stalwart caches
   these lookups in 0.16 is unknown. If uncached, every JMAP request from
   bulwark adds a round-trip to Kanidm. Measure in sandbox; consider
   fallback if it's per-request.
4. **Session invalidation.** Switching bulwark's issuer invalidates all
   existing bulwark sessions (tokens minted by stalwart are no longer the
   login path). Minor, one-time; users just log in again via Kanidm.

## Pre-merge sandbox test checklist

On a throwaway stalwart 0.16.8 instance (same pattern as the 0.16 upgrade
sandbox), pointed at the real (or a test) Kanidm:

- [ ] Apply a plan containing the `Oidc` Directory create; confirm
      `stalwart-cli` reports zero failed operations and re-apply is
      idempotent (destroy-all + create twice in a row)
- [ ] Confirm internal-directory **password auth still works** after the
      Directory op exists (IMAP `AUTH PLAIN`, JMAP basic auth)
- [ ] Obtain a token from Kanidm as a `bulwark-webmail_users` member
      (auth-code + PKCE, e.g. via bulwark itself or oidc-token.sh pattern)
- [ ] IMAP `XOAUTH2` with the Kanidm access token → authenticates as the
      mapped account (`daniel@lyte.dev` → `daniel`)
- [ ] JMAP `Authorization: Bearer <kanidm token>` → session for `daniel`
- [ ] Token minted for a *different* Kanidm client is **rejected**
      (`requireAudience` enforcement)
- [ ] Check stalwart logs for userinfo call frequency (caching behavior,
      caveat 3)
- [ ] Full bulwark login flow end-to-end against the sandbox

## Post-merge follow-ups

- Remove the now-unused stalwart-internal `OAuthClient` for
  `bulwark-webmail` from the plan
- Add other webmail users to `bulwark-webmail_users` as needed
