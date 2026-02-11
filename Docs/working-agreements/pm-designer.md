# PM ↔ Designer working agreement (HackPanel)

This doc is the lightweight contract for how Product (PM) and Design collaborate on HackPanel work.

## Goals
- Keep PRs small and mergeable.
- Minimize rework by aligning on scope + acceptance criteria early.
- Ensure “polish” work is shippable and doesn’t sprawl.

## Default workflow
1) **PM owns scope & acceptance criteria**
   - Each issue should have: goal, in-scope / out-of-scope, acceptance criteria, and a PR-sized target.

2) **Designer owns UX guidance**
   - Provide: copy, states (empty/loading/error), and a11y notes.
   - If a screenshot/mock is needed, keep it narrowly scoped to the slice.

3) **Engineer/agent owns implementation details**
   - Keep to the slice boundaries; open follow-up issues instead of expanding scope.

## Slice sizing rules
- Prefer **S/XS PRs** that can be reviewed quickly.
- If an issue can’t be executed without external data (protocol capture, credentials, etc.), **block it explicitly** and request the smallest missing input.

## PR communication (required)
Before merging any active PR, leave **at least one** short PR comment using this template:

```text
Cross-agent comms

Context: <what problem this solves / why now>
Change: <what changed>
Risk/impact: <what could break>
Testing: <what you ran / what CI covers>
Follow-ups: <anything intentionally deferred>
```

Notes:
- This is not a formal review requirement; it’s a coordination checkpoint.
- Keep it brief. The goal is to reduce surprise merges.
