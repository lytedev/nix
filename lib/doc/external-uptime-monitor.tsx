// Snapshot (for the record) of the off-site uptime watcher — Tier 0 in
// lib/doc/alerting.md. This is NOT built or deployed by the flake; it runs as a
// val.town cron. The live source is authoritative and this copy drifts if the
// val is edited:
//   https://www.val.town/x/lytedev/SimpleSiteUptimeMonitor/code/main.tsx
//
// It GETs each site on a schedule and emails (via val.town's own std/email,
// independent of beefcake's Stalwart) if any returns >= 400 or fails to fetch —
// the dead-man's-switch for a total beefcake/Caddy outage.

import { email } from "https://esm.town/v/std/email";

const sites = [
  "https://files.lyte.dev",
  "https://openobserve.h.lyte.dev",
];

export async function emailIfSiteIsDown(url: string): Promise<boolean> {
  const [date, time] = new Date().toISOString().split("T");
  let ok = true;
  let reason: string;
  try {
    const res = await fetch(url);
    if (res.status >= 400) {
      reason = `HTTP error status code: ${res.status})`;
      ok = false;
    }
  } catch (e) {
    reason = `couldn't fetch: ${e}`;
    ok = false;
  }
  if (!ok) {
    const subject = `${url} down`;
    const text = `At ${date} ${time} (UTC), ${url} was down: ${reason}`;
    console.error(subject, text);
    await email({ subject, text });
  } else {
    console.log(`${url} ok`);
  }
  return ok;
}

export default async function checkSites() {
  await Promise.allSettled(sites.map(emailIfSiteIsDown));
}
