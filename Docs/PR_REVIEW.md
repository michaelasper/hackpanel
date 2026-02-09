# PR Review Checklist (HackPanel)

We use `gh` for PR workflow. By default, leave feedback via **PR comments** (not formal reviews) unless the author asks for a formal review.

## Reviewer checklist

Baseline
- Build + run (app launches, no obvious warnings/crashes)
- Tests green (`swift test` locally or CI)

UI (if applicable)
- Matches screenshots/recording
- Empty/loading/error states checked
- Keyboard/focus/tab order reasonable

Liquid Glass slices (required quick QA)
- Toggle Light/Dark
- Toggle Reduce Transparency
- Toggle Increased Contrast
- Bump text size (at least one larger step)
- VoiceOver pass: primary actions discoverable; avoid duplicate status narration

Error handling
- Failure paths handled; user errors are actionable
- Logs helpful; no sensitive leaks

Security
- No secrets/tokens/PII in code/logs/fixtures
- Credentials/storage uses Keychain where appropriate

Accessibility
- Labels/roles present; keyboard-only flow works
- VoiceOver: doesn’t read duplicate/competing status messages (banner vs empty-state, etc.)
- Legibility/contrast reasonable
- Larger text sizes: no truncation of primary actions
- Increased Contrast (if enabled): still legible and not visually “blown out”
- Reduce Transparency: glass surfaces fall back to solid semantic backgrounds + borders (no blur)

Concurrency / architecture
- UI updates on `@MainActor`
- Async work not blocking main thread; tasks cancellable where relevant
- Actor boundaries sensible; avoid data races / Sendable issues

API contract / decoding
- Decoding resilient (optional fields/defaults); failures surfaced cleanly
- Fixtures/tests updated if response shape changed

Docs / AC alignment
- Matches acceptance criteria and scope
- Docs updated when behavior/setup/workflow changes

## PR feedback comment template

Paste as a **PR comment**:

```text
PR Review (HackPanel)

Summary
- <1–2 lines: what changed + overall status>

✅ Looks good
- <bullets of what’s solid>

🛑 Blocking (must fix before merge)
- [ ] <issue + file/line if possible + expected behavior>

⚠️ Non-blocking suggestions (nice to have)
- <improvement idea>

Questions / clarifications
- <question>

Verification notes
- Build: <local/CI> | Tests: <swift test/CI> | UI: <what you manually checked>
- Concurrency: <anything you verified about MainActor/actors>
- API decoding: <payload/fixture checked?>
- Accessibility: <keyboard/focus/labels>
```
