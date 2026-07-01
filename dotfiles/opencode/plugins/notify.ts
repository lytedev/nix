import type { Plugin } from "@opencode-ai/plugin"

const Notify: Plugin = async (ctx) => {
  // Build a from-URI with context (similar to claude-hook)
  async function buildFrom(): Promise<string> {
    const user =
      (await ctx.$`whoami`.quiet().nothrow().text()).trim() || "unknown"
    const host =
      (await ctx.$`hostname -s`.quiet().nothrow().text()).trim() || "unknown"
    const cwd = ctx.directory

    const parts: string[] = []
    parts.push(`pid=${process.pid}`)

    // Herdr context. herdr injects the workspace/tab/pane ids of the current
    // pane, so no query is needed to locate ourselves.
    if (process.env.HERDR_ENV === "1") {
      const workspace = process.env.HERDR_WORKSPACE_ID || ""
      const tab = process.env.HERDR_TAB_ID || ""
      const pane = process.env.HERDR_PANE_ID || ""
      const loc = [workspace, tab, pane].filter(Boolean).join(".")
      if (loc) parts.push(`herdr=${encodeURIComponent(loc)}`)
    }

    // Niri window ID for focus-on-click
    try {
      const niriJson = await ctx.$`niri msg focused-window --json`
        .quiet()
        .nothrow()
        .text()
      const niriId = JSON.parse(niriJson)?.id
      if (niriId) parts.push(`niri_window=${niriId}`)
    } catch {}

    return `${user}@${host}:${cwd}?${parts.join("&")}`
  }

  // Debounce: skip if we notified very recently
  let lastNotifyTime = 0
  const DEBOUNCE_MS = 3000

  async function notify(
    type: string,
    title: string,
    body: string,
    urgency: string,
  ) {
    const now = Date.now()
    if (now - lastNotifyTime < DEBOUNCE_MS) return
    lastNotifyTime = now

    const from = await buildFrom()
    // setsid detaches pw-play so it isn't killed when the shell command returns
    await ctx
      .$`setsid claude-notify --type ${type} --title ${title} --body ${body} --urgency ${urgency} --from ${from}`
      .quiet()
      .nothrow()
  }

  return {
    async event({ event }) {
      if (
        event.type === "session.status" &&
        event.properties.status.type === "idle"
      ) {
        await notify("idle", "opencode", "Session idle", "normal")
      }

      if (event.type === "permission.asked") {
        await notify(
          "permission",
          "opencode",
          "Permission needed",
          "critical",
        )
      }
    },
  }
}

export default Notify
