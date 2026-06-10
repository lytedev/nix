# Stalwart ↔ Kanidm OIDC integration (bulwark webmail SSO)

**Labels**: mail, stalwart, kanidm, sso
**Related**: issues/open/stalwart-0.16-upgrade.md

**Status**: DRAFT — config landed, **needs sandbox verification before merge/deploy**.
Source-level analysis of stalwart v0.16.8 (below) answers most design
questions but also surfaces an **activation blocker** (see "Authentication
arbitration") that must be confirmed and resolved before this delivers
working SSO.

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
     `daniel`, not the SPN `daniel@idm.h.lyte.dev` — **required**, see
     "Identity overlap" below.
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

## Identity overlap: kanidm `daniel` must resolve to the existing stalwart `daniel`

Requirement: OIDC-authenticated sessions must resolve to the **same stalwart
principal** (existing account id, name `daniel`, email `daniel@lyte.dev`,
existing mailbox) — not auto-provision a parallel account.

The following is a **source-level analysis of stalwart v0.16.8** (tag
`v0.16.8` = commit `26f41f8`), pending sandbox confirmation. The official
docs ([stalw.art/docs/auth/backend/oidc](https://stalw.art/docs/auth/backend/oidc/),
not version-pinned) describe the claim mapping and JIT provisioning but not
the matching mechanics; the mechanics below come from the source.

### How an OIDC identity is matched to an account

The OIDC backend never creates its own principal space. It produces an
**email address** from claims, and the core resolves that email through the
*same* account namespace internal accounts live in:

1. `resolve_email` ([oidc/lookup.rs#L227-L250](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/backend/oidc/lookup.rs#L227-L250)):
   take the `claimUsername` claim; if it contains `@` use it verbatim,
   otherwise append `usernameDomain`. (If the configured claim is absent it
   falls back to the `email` claim.) For us: `daniel` + `lyte.dev` →
   `daniel@lyte.dev`.
2. `synchronize_account` ([cache/directory.rs#L31-L155](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/cache/directory.rs#L31-L155)):
   split the email into local part + domain, require the domain to be an
   existing stalwart Domain, then `account_id_from_parts("daniel",
   domain_id)` ([cache/principals.rs#L544-L558](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/cache/principals.rs#L544-L558))
   — a lookup by local-part within the domain.
   - **Hit → the existing account record and id are reused as-is.** The
     access token is built from that id; mailbox data is shared by
     construction. Overlap is what the code does, not a side effect.
   - Miss → JIT-creates a new `UserAccount` named after the local part
     ([cache/directory.rs#L156-L241](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/cache/directory.rs#L156-L241))
     — this is the shadow-account path we must show is *not* taken for
     `daniel`.

### Name collision semantics

There is no "collision" in the LDAP-sync sense: external and internal
accounts share one namespace, and the external login resolves **to** the
internal record (internal wins; mail data shared, same id). On a match the
sync may *mutate* the existing record, limited to:

- `description` — updated from `claimName` (`name` claim) when different.
  Cosmetic; kanidm's displayname for daniel should match what's there.
- password — only if the directory returns a secret; the OIDC backend
  always returns `secret: None`
  ([oidc/lookup.rs#L201-L225](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/backend/oidc/lookup.rs#L201-L225)),
  so the **internal password is never touched**.
- group memberships — only if `claimGroups` is configured; we deliberately
  leave it unset so kanidm groups cannot rewrite stalwart group/role
  membership (`adminAccounts` role grants stay authoritative).

### Failure modes (and why `oauth2_prefer_short_username` is load-bearing)

- **SPN claim** (`daniel@idm.h.lyte.dev`, kanidm's default): contains `@`,
  used verbatim → `idm.h.lyte.dev` is not a stalwart Domain → auth **fails
  closed** ("Account domain does not exist"). No shadow account, but SSO is
  broken — hence `oauth2_prefer_short_username: true` on the kanidm client
  is a hard dependency. Kanidm documents that "By default Kanidm will use
  SPN as a display username", switchable per client via
  `kanidm system oauth2 prefer-short-username <client>`
  ([kanidm book: OAuth2](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html)).
  The HJSON migration sets the equivalent `oauth2_prefer_short_username`
  attribute (same pattern as `matrix.lyte.dev` in 20-oauth2.hjson).
- **Kanidm user with no stalwart account** (e.g. someone added to
  `bulwark-webmail_users` later): JIT-creates `<name>@lyte.dev` with no
  password and default User role. Membership of `bulwark-webmail_users` is
  therefore the provisioning gate — keep it tight, and pre-create stalwart
  accounts before adding people.

## Authentication arbitration (caveat 1 — now analyzed, still a blocker)

Source-level findings, v0.16.8:

- The internal directory is **not a `Directory` object**: the registry
  `Directory` enum has only `Ldap | Sql | Oidc` variants
  ([core/config.rs#L19-L40](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/core/config.rs#L19-L40)).
  So our destroy-all `Directory` plan op **cannot delete internal auth**
  (resolves former caveat 2 at source level; still re-check in sandbox).
- A Directory participates in auth **only as the default directory**,
  selected by `directoryId` on the `Authentication` singleton
  ([core/config.rs#L42-L56](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/core/config.rs#L42-L56)).
  Per-domain directory binding exists but is **enterprise-gated**
  ([authentication.rs#L506-L542](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/auth/authentication.rs#L506-L542)).
- **Bearer tokens** (JMAP `Authorization: Bearer`, IMAP XOAUTH2/OAUTHBEARER):
  if a default directory exists and it's OIDC, stalwart tries it first and
  **falls back to internal OAuth** on failure
  ([authentication.rs#L346-L377](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/auth/authentication.rs#L346-L377)).
  Good: both token kinds coexist.
- **Basic auth (passwords)**: if a default directory is set, Basic goes to
  it **exclusively — no fallback** to internal password verification
  ([authentication.rs#L171-L248](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/common/src/auth/authentication.rs#L171-L248);
  the internal-password branch is the `else` of "directory configured"),
  and the OIDC backend rejects Basic credentials outright
  ([oidc/lookup.rs#L37-L40](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/backend/oidc/lookup.rs#L37-L40)).

**Consequence (the blocker)**, in the community edition:

- `Authentication.directoryId` **unset** (what this PR ships): the Oidc
  directory is inert — kanidm bearer tokens are never consulted, bulwark
  login fails at the JMAP stage. Safe but non-functional.
- `Authentication.directoryId` **set** to the Oidc directory: bearer auth
  works (OIDC-first, internal-OAuth fallback), but **IMAP/SMTP `AUTH PLAIN`
  breaks** — exactly what we must not do.

So 0.16.8 CE appears unable to do "internal passwords + OIDC bearer"
simultaneously. The sandbox must confirm this reading; if confirmed, options:

1. Upstream feature request: fall back to internal password verification
   when the default directory rejects Basic (or bearer-only directory
   routing). The bearer path already has exactly this fallback shape.
2. Enterprise per-domain directory binding (license).
3. Stay on stalwart-internal OAuth for bulwark (status quo) until upstream
   supports coexistence.

## Remaining caveats

1. ~~Directory arbitration unknown~~ → analyzed above; **blocker pending
   sandbox confirmation**.
2. ~~Destroy-all `Directory` might nuke internal auth~~ → internal directory
   is not a `Directory` object (source-verified); re-check in sandbox anyway.
3. **Token validation cost**: JWTs are validated locally against cached JWKS
   (5-min refresh window); the **userinfo endpoint is only called for opaque
   tokens or when the JWT lacks the username claim**
   ([oidc/lookup.rs#L80-L104](https://github.com/stalwartlabs/stalwart/blob/26f41f8aa78fd6daa4cfc88bb57708a8b93a80be/crates/directory/src/backend/oidc/lookup.rs#L80-L104)).
   Kanidm access tokens are JWTs, but whether `preferred_username` is in the
   *access* token (vs only userinfo/id_token) determines per-request userinfo
   round-trips. Measure in sandbox.
4. **Session invalidation**: switching bulwark's issuer invalidates existing
   bulwark sessions. Minor, one-time; users re-login via Kanidm.

## Pre-merge sandbox test checklist

On a throwaway stalwart 0.16.8 instance (same pattern as the 0.16 upgrade
sandbox), pointed at the real (or a test) Kanidm:

- [ ] Apply a plan containing the `Oidc` Directory create; confirm
      `stalwart-cli` reports zero failed operations and re-apply is
      idempotent (destroy-all + create twice in a row)
- [ ] Confirm internal-directory **password auth still works** after the
      Directory op exists (IMAP `AUTH PLAIN`, JMAP basic auth)
- [ ] **Arbitration**: with `Authentication.directoryId` unset, check whether
      a kanidm bearer token is accepted at all (prediction: no). Then set
      `directoryId` to the Oidc directory and re-test `AUTH PLAIN`
      (prediction: breaks). Record actual behavior — this decides the
      go/no-go and the upstream ask.
- [ ] Obtain a token from Kanidm as a `bulwark-webmail_users` member
      (auth-code + PKCE, e.g. via bulwark itself or oidc-token.sh pattern)
- [ ] **Claim check**: decode the kanidm access token / userinfo response and
      verify `preferred_username` is exactly `daniel` (short name, no SPN) —
      confirms `oauth2_prefer_short_username` took effect
- [ ] **Identity overlap**: before first OIDC login, record the existing
      `daniel` account id (e.g. `stalwart-cli query Account` /
      `stalwart-cli describe Account daniel`) and total Account count.
      After authenticating with the kanidm token:
      - [ ] the session/auth-log `AccountId` equals the pre-existing id, and
            the mailbox seen over JMAP/IMAP is daniel's existing mailbox
      - [ ] `stalwart-cli query Account` count is **unchanged** (no shadow
            account JIT-provisioned)
      - [ ] the `daniel` account record was not unexpectedly mutated
            (password credential intact; description change from `claimName`
            is the only acceptable diff)
- [ ] IMAP `XOAUTH2` with the Kanidm access token → authenticates as the
      mapped account
- [ ] JMAP `Authorization: Bearer <kanidm token>` → session for `daniel`
- [ ] Token minted for a *different* Kanidm client is **rejected**
      (`requireAudience` enforcement)
- [ ] Negative test: kanidm user in `bulwark-webmail_users` with **no**
      stalwart account → observe (and document) the JIT-provisioning
      behavior, confirm it cannot collide with existing mailboxes
- [ ] Check stalwart logs for userinfo call frequency (caveat 3)
- [ ] Full bulwark login flow end-to-end against the sandbox

## References

- Stalwart OIDC directory docs (claim mapping, JIT provisioning, no
  proactive auto-create): <https://stalw.art/docs/auth/backend/oidc/>
  (upstream docs are not version-pinned)
- Source permalinks above are pinned to tag `v0.16.8`
  (`26f41f8aa78fd6daa4cfc88bb57708a8b93a80be`)
- Kanidm OAuth2 book (SPN default / `prefer-short-username`):
  <https://kanidm.github.io/kanidm/stable/integrations/oauth2.html>

## Post-merge follow-ups

- Remove the now-unused stalwart-internal `OAuthClient` for
  `bulwark-webmail` from the plan
- Add other webmail users to `bulwark-webmail_users` as needed (pre-create
  their stalwart accounts first — see identity overlap notes)
- File the upstream issue if the arbitration blocker is confirmed
