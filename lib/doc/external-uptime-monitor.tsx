// Snapshot (for the record) of the off-site uptime watcher — Tier 0 in
// lib/doc/alerting.md. This is NOT built or deployed by the flake; it runs as a
// val.town cron. The live source is authoritative and this copy drifts if the
// val is edited:
//   https://www.val.town/x/lytedev/SimpleSiteUptimeMonitor/code/main.tsx
//
// On failure it fires BOTH channels:
//   - email via val.town's std/email (a durable record / backup), and
//   - a push to self-hosted ntfy on pebble (the reliable, beefcake-independent
//     alert; ntfy.e.lyte.dev, see packages/hosts/pebble/ntfy.nix).
// ntfy matters because email to @lyte.dev is delivered by beefcake's Stalwart,
// so it can't reach you during the very outage this is meant to catch; ntfy is
// a push read by a phone app, hosted on pebble (not beefcake) — no beefcake
// dependency end to end.
//
// Config comes from val.town environment variables (Settings → Environment
// Variables), set via the val.town API (not committed):
//   NTFY_URL     required. Full topic URL: https://ntfy.e.lyte.dev/infra-alerts
//   NTFY_TOKEN   required for the private topic. An ntfy access token for the
//                `alerts` user (deny-all server); sent as a Bearer token.
//                If unset, only email is sent.

import { email } from "https://esm.town/v/std/email";

// Hit each service's health/semantic endpoint, not its root: several serve a
// 404/redirect at "/" even when perfectly healthy, and a health path also
// confirms the backend actually serves (not just that Caddy answered).
const sites = [
  "https://files.lyte.dev/",
  "https://mail.lyte.dev/healthz/live", // Stalwart liveness (root 404s)
  "https://git.lyte.dev/api/healthz", // Forgejo
  "https://matrix.lyte.dev/_matrix/client/versions", // Matrix client-server API
  "https://openobserve.h.lyte.dev/healthz", // OpenObserve
];

const NTFY_URL = Deno.env.get("NTFY_URL");
const NTFY_TOKEN = Deno.env.get("NTFY_TOKEN");

// Push to ntfy. Metadata goes in headers; header values must be ASCII, so emoji
// use the `Tags` header (rendered by the app), never the Title. Priority 5
// ("urgent") so it can punch through phone Do-Not-Disturb.
async function pushNtfy(title: string, message: string): Promise<void> {
  if (!NTFY_URL) {
    console.error("NTFY_URL unset — skipping ntfy push");
    return;
  }
  const headers: Record<string, string> = {
    Title: title,
    Priority: "urgent",
    Tags: "rotating_light",
  };
  if (NTFY_TOKEN) headers.Authorization = `Bearer ${NTFY_TOKEN}`;
  try {
    const res = await fetch(NTFY_URL, { method: "POST", headers, body: message });
    if (!res.ok) console.error(`ntfy push failed: HTTP ${res.status}`);
  } catch (e) {
    console.error(`ntfy push failed: ${e}`);
  }
}

export async function checkSite(url: string): Promise<boolean> {
  const [date, time] = new Date().toISOString().split("T");
  let reason: string | undefined;
  try {
    const res = await fetch(url);
    if (res.status >= 400) reason = `HTTP ${res.status}`;
  } catch (e) {
    reason = `couldn't fetch: ${e}`;
  }
  if (reason) {
    const subject = `${url} down`;
    const text = `At ${date} ${time} (UTC), ${url} was down: ${reason}`;
    console.error(subject, text);
    // Fire both channels; a failure in one must not suppress the other.
    await Promise.allSettled([
      email({ subject, text }),
      pushNtfy(`${url} is DOWN`, text),
    ]);
    return false;
  }
  console.log(`${url} ok`);
  return true;
}

export default async function checkSites() {
  await Promise.allSettled(sites.map(checkSite));
}
