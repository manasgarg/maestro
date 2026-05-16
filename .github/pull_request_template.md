## Observable change

<!-- What is now different that the human can see, do, or measure? One or two sentences in the user's vocabulary. -->

## Runbook

<!-- Cite .maestro/evidence/<dir>/runbook.md — the narrated demo a human can read top-to-bottom to assess the work without running anything. -->

See `.maestro/evidence/<dir>/runbook.md`.

## Evidence

<!--
For each acceptance criterion from the direction's proposal:
- the assertion label in verify.sh that tests it,
- the captured pass status in verification.log (or per-criterion log).
The implementer ran the verification. Cite recordings, not instructions.
-->

- Criterion 1: `verify.sh:<assertion label>` → `.maestro/evidence/<dir>/verification.log`
- Criterion 2:

## Test mapping (criterion ↔ assertion)

<!-- Explicit binding. Reviewer audits this. Each criterion must map to a named assertion in verify.sh. -->

- Criterion 1 → `verify.sh:<assertion label>`
- Criterion 2 →

## Test-catches-it

<!-- Captured proof the assertions fail when the underlying code/doc is broken. Without this, a passing test could be vacuous. -->

`.maestro/evidence/<dir>/test-catches-it.log`

## Pre-mortem (non-atomic only)

<!-- Required for non-atomic direction: at least five named failure modes the implementer addressed. Delete this section for atomic PRs. -->

See `.maestro/evidence/<dir>/pre-mortem.md`.

## Counterfactual (non-atomic only)

<!-- Required for non-atomic direction: runbook re-executed with the change reverted, captured as failing. Delete for atomic PRs. -->

See `.maestro/evidence/<dir>/counterfactual.md`.

## Bug Hunter findings (non-atomic only)

<!-- Adversarial pass output. Each finding either addressed in the diff or disclosed below. Delete for atomic PRs. -->

See `.maestro/evidence/<dir>/bug-hunter.log`.
- Addressed: <commits/files>
- Disclosed (won't fix): <list with reasoning>

## Open AI feedback

<!-- Any Reviewer comments not yet addressed and why. Leave blank if none. -->

---

Closes #
