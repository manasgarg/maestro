## Observable change

<!-- What is now different that the human can see, do, or measure? One or two sentences in the user's vocabulary. -->

## Demo

<!--
A numbered, narrated walk-through the human can read top-to-bottom without
running any code. Each step cites a captured artifact under
`.maestro/evidence/<issue-number>/` that proves it (a log line, a
screenshot, a file path with a line range, a command output).

The human reads the demo, sees the artifact for each step, and decides.
Do not link to "run this command" — the artifact must already exist in the
diff, captured by you.

Example:
1. Open the new sign-in page — see the SSO button → screenshot:
   `.maestro/evidence/42/01-signin-page.png`
2. Click SSO with a wrong domain — see the inline error → log line:
   `.maestro/evidence/42/02-bad-domain.log:7`
3. Click SSO with a valid domain — redirected to the dashboard → screenshot:
   `.maestro/evidence/42/03-dashboard.png`
-->

1.
2.

## Evidence

<!--
For each acceptance criterion from the direction's proposal, cite both:
  - the captured demo artifact (from the Demo section above), and
  - the automated test that will catch a regression — by test name and
    repo-relative path, runnable by `tools/run_tests.sh` (the script the
    Maestro CI workflow invokes).

For non-trivial direction, also cite the captured failing log produced when
the change was reverted — proves the change is doing work, not a no-op.
Conventional path: `.maestro/evidence/<issue>/revert-demo.log`.

Criteria you genuinely could not self-verify: flag explicitly with the
reason. Do not silently omit.
-->

- Criterion 1: demo step <n>; test `<path/to/test>`
- Criterion 2: demo step <n>; test `<path/to/test>`
- Anti-no-op (non-trivial direction): `.maestro/evidence/<issue>/revert-demo.log`

## Pre-mortem

<!--
Named list of things that could go wrong and what you did about each
*before* opening this PR. Real risks specific to this change — not generic
"could have bugs". 3–5 entries is typical; more for risky changes.

Each entry: one line naming the risk, one line on the mitigation.
-->

- Risk:
  Mitigation:
- Risk:
  Mitigation:

## Adversarial pass

<!--
Before opening this PR you ran a separate adversarial review whose only
job was to find bugs. Its captured output lives at
`.maestro/evidence/<issue>/adversarial-review.md`. Summarize:

- what it flagged,
- which items you fixed (link the commit), and
- which items you decided not to fix and why.

If it flagged nothing, say so and link the empty review.
-->

- Findings:
- Addressed:
- Deliberately not addressed (and why):

## Open AI feedback

<!-- Reviewer or Adversarial-Reviewer comments not yet addressed and why. Leave blank if none. -->

---

Closes #
