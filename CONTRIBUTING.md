# Contributing to HackPanel

## PR rules (short version)
- Keep PRs single-purpose and small when possible.
- CI must be green before merge.
- For UI changes: include screenshots/screen recording and note accessibility checks.
- Never commit secrets (tokens/keys), even in fixtures.


## Coordination & review
- Use the reviewer checklist + PR comment template: `Docs/PR_REVIEW.md`.
- **Before merging any active PR**, leave at least one short **cross-agent comms** PR comment (Context / Change / Risk / Testing / Follow-ups).
  - See: `Docs/working-agreements/pm-designer.md` (template included).

## Branch naming
- `feature/<short-name>`
- `fix/<short-name>`
- `chore/<short-name>`

## Local dev
- Open `Package.swift` in Xcode.
- Run `HackPanelApp`.
- Tests: `swift test`.

### Optional: XcodeBuildMCP (agent build/test feedback loop)
If you want an AI coding agent to run Xcode builds/tests and return structured failures, set up Sentry’s **XcodeBuildMCP**:
- `Docs/Tooling/XcodeBuildMCP.md`

### SPM sanity check (matches CI)
Run the same commands CI runs:

```bash
./Scripts/spm_sanity_check.sh
```
