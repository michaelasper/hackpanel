# BACKLOG

This file is the canonical place to keep small, sliceable work items.

## Next (1–2 slices each)
- Gateway health card: show connection/status + last check timestamp.
- Nodes list (minimal): paired nodes, online/offline, last seen.
- Empty/error states: make “no gateway / no nodes” paths look intentional.
- Basic diagnostics: “Copy debug info” button (app version, OS, gateway URL, last error).

## Soon
- Provider/integration health (read-only): list providers + OK/Degraded.
- Logs view: tail latest gateway logs + quick filter.
- Export diagnostics bundle (zip): logs + config summary (no secrets).
- Settings storage: persist gateway endpoint + user prefs.

## Later
- Keychain-backed secrets + signed-in providers.
- Auto-refresh tuning + background refresh.
- Search/sort/pin nodes; per-node detail view.
- Theming/polish (liquid glass refinements) + onboarding flow.
