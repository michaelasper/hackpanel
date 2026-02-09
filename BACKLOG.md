# BACKLOG

This file is **not** canonical anymore.

**Canonical backlog:** GitHub Project “hackpanel” — https://github.com/users/michaelasper/projects/2

Use this file only as a pointer and (optional) short-lived snapshot when helpful for discussion.

## Next (1–2 slices each)
- Empty/error states: make “no gateway / no nodes” paths look intentional (primary actions: Open Settings, Retry, View diagnostics).
- Logs view: show recent gateway logs + lightweight filter/search (fast debugging loop).

## Soon
- Export diagnostics bundle (zip): logs + redacted config summary (no secrets).
- Provider/integration health (read-only): list providers + OK/Degraded.

## Later
- Keychain-backed secrets + signed-in providers.
- Auto-refresh tuning + background refresh.
- Search/sort/pin nodes; per-node detail view.
- Theming/polish (liquid glass refinements) + onboarding flow.

## Done (recent)
- Gateway health card (connection/status + last check timestamp).
- Nodes list (minimal): paired nodes, online/offline, last seen.
- Basic diagnostics: “Copy debug info” button.
- Settings storage: persist gateway endpoint + user prefs.
