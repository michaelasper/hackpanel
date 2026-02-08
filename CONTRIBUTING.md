# Contributing to HackPanel

## PR rules (short version)
- Keep PRs single-purpose and small when possible.
- CI must be green before merge.
- For UI changes: include screenshots/screen recording and note accessibility checks.
- Never commit secrets (tokens/keys), even in fixtures.

## Branch naming
- `feature/<short-name>`
- `fix/<short-name>`
- `chore/<short-name>`

## Local dev
- Open `Package.swift` in Xcode.
- Run `HackPanelApp`.
- Tests: `swift test`.
