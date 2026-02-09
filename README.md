# HackPanel

macOS-native “liquid glass” first dashboard for **OpenClaw Gateway**.

## Goals (v0)
- At-a-glance Gateway health.
- Nodes list (paired/online/last seen).
- Provider/integration health (read-only to start).
- Logs/diagnostics export (later v0).

## Build & Run (local)
Open `Package.swift` in Xcode and run the `HackPanelApp` executable scheme.

### SPM sanity check (build + tests)
```bash
./Scripts/spm_sanity_check.sh
```

## Repo hygiene
- No secrets in repo. Tokens belong in Keychain (later) or local-only settings files (gitignored).
- PRs must keep scope tight and keep CI green.
