# PR Review Checklist (HackPanel)

We use `gh` for PR workflow, and we leave feedback via **PR comments** (not formal GitHub reviews).

## Reviewer checklist (short)

Baseline
- Build + run (app launches; no obvious warnings/crashes)
- Tests green (`swift test` locally or CI)

UI (if applicable)
- Matches description + screenshots/recording
- Loading/empty/error states checked
- Keyboard/focus/tab order reasonable

Error handling
- Failure paths handled; user-visible errors actionable
- Logs helpful; avoid leaking sensitive info

Security
- No secrets/tokens/PII in code/logs/fixtures
- Credentials/storage uses Keychain when appropriate

Accessibility
- Controls have labels/roles; keyboard-only flow works
- Legibility/contrast reasonable

Concurrency / architecture (Swift)
- UI updates on `@MainActor`
- Async work not blocking main thread; tasks cancellable where relevant
- Actor boundaries sensible; avoid data races / `Sendable` issues

API contract / decoding
- Decoding resilient (optional fields/defaults); failures surfaced cleanly
- Fixtures/tests updated if response shape changed

Docs / AC alignment
- Matches acceptance criteria and scope
- Docs updated when behavior/setup/workflow changes

## Standard PR feedback template (paste as a PR comment)

```text
PR Review (HackPanel)

Summary
- <1–2 lines: what changed + overall status>

✅ Looks good
- <bullets>

🛑 Blocking (must fix before merge)
- [ ] <issue + where + expected behavior>

⚠️ Non-blocking suggestions
- <idea>

Questions
- <question>

Verification notes
- Build: <local/CI> | Tests: <swift test/CI> | UI: <manual checks>
- Concurrency: <MainActor/actors notes>
- API decoding: <payload/fixture checked?>
- Accessibility: <keyboard/focus/labels>
```
