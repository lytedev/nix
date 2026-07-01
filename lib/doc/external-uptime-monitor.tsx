// Snapshot (for the record) of the off-site uptime watcher — Tier 0 in
// lib/doc/alerting.md. This is NOT built or deployed by the flake; it runs as a
// val.town cron. The live source is authoritative and this copy drifts if the
// val is edited:
//   https://www.val.town/x/lytedev/SimpleSiteUptimeMonitor/code/main.tsx
//
// It GETs each public endpoint on a schedule and, on failure, pushes to
// ntfy.sh. ntfy is used instead of email deliberately: it is a hosted push
// service reached with a single fetch and read by a phone app, so BOTH the
// detection and the notification stay entirely off beefcake — unlike email,
// whose @lyte.dev delivery depends on beefcake's Stalwart and so cannot reach
// you during the very outage this is meant to catch.
//
// Config comes from val.town environment variables (Settings → Environment
// Variables), so the topic stays out of version control — a public ntfy topic
// is readable by anyone who knows its name:
//   NTFY_TOPIC   required. Prefer a RESERVED topic on a free ntfy.sh account
//                (Access → reserve) so it can require auth, rather than a
//                guessable public one.
//   NTFY_TOKEN   optional. Bearer token for a reserved/private topic. If unset,
//                the topic is treated as public.
//   NTFY_SERVER  optional. Defaults to https://ntfy.sh.

const sites = [
  "https://files.lyte.dev",
  "https://mail.lyte.dev",
  "https://git.lyte.dev",
  "https://matrix.lyte.dev",
  "https://openobserve.h.lyte.dev",
];

const NTFY_SERVER = Deno.env.get("NTFY_SERVER") ?? "https://ntfy.sh";
const NTFY_TOPIC = Deno.env.get("NTFY_TOPIC");
const NTFY_TOKEN = Deno.env.get("NTFY_TOKEN");

// Push a notification. ntfy takes metadata via headers; header values must be
// ASCII, so emoji go through the `Tags` header (rendered by the app), never the
// Title. Priority 5 ("urgent") so it can punch through phone Do-Not-Disturb.
async function push(title: string, message: string): Promise<void> {
  if (!NTFY_TOPIC) {
    console.error("NTFY_TOPIC is unset — cannot send push");
    return;
  }
  const headers: Record<string, string> = {
    Title: title,
    Priority: "urgent",
    Tags: "rotating_light",
  };
  if (NTFY_TOKEN) headers.Authorization = `Bearer ${NTFY_TOKEN}`;
  try {
    const res = await fetch(`${NTFY_SERVER}/${NTFY_TOPIC}`, {
      method: "POST",
      headers,
      body: message,
    });
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
    console.error(`${url} down: ${reason}`);
    await push(`${url} is DOWN`, `At ${date} ${time} UTC, ${url} was down: ${reason}`);
    return false;
  }
  console.log(`${url} ok`);
  return true;
}

export default async function checkSites() {
  await Promise.allSettled(sites.map(checkSite));
}
