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

Error handling
- Failure paths handled; user errors are actionable
- Logs helpful; no sensitive leaks

Security
- No secrets/tokens/PII in code/logs/fixtures
- Credentials/storage uses Keychain where appropriate

Accessibility
- Labels/roles present; keyboard-only flow works
- Legibility/contrast reasonable

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
