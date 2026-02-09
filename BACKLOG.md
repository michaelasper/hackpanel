# BACKLOG

This file is the canonical place to keep small, sliceable work items.

## P0 — Liquid Glass redesign/refactor (v1)
### Design system primitives (start here)
- AppTheme tokens: spacing/radius, glass paddings, border/shadow constants.
- GlassSurface: material fill + border + elevation (single source of truth).
- GlassCard: standardized padded surface for cards.
- Typography baseline: title/subtitle/body/caption weights used consistently across views.
- Motion/interaction: hover/press feedback for glass surfaces (where appropriate on macOS).
- Accessibility: contrast checks, reduce transparency support, VoiceOver labels for key UI.
- Preview/demo: "GlassDemoView" (and/or SwiftUI previews) to iterate quickly.

### Apply primitives to v1 surfaces
- Dashboard: all sections use consistent glass cards + headers.
- Nodes: list + empty/error states feel native to the glass system.
- Settings: form grouping and panels match the system.
- Connection banner: align with the new glass language (material + separator + typography).

### V1 polish guardrails
- No new product scope while P0 is underway (only cosmetic refactors + small UX fixes).
- Keep primitives small; avoid premature component explosion.

## P1 — Product utility (resume after glass v1)
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
- Theming/polish (post-v1 refinements) + onboarding flow.
