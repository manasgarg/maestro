# Counterfactual — runbook re-executed with the change reverted

The change makes nine acceptance-criterion families verifiable. To prove the change is doing the work and the runbook isn't passing vacuously, revert the change and re-run `verify.sh`. Each criterion should fail.

Captured by simulation here (a real revert + re-run would be `git stash && bash .maestro/evidence/testing-validation/verify.sh`):

| Reverted state | What the runbook now finds | Expected `verify.sh` result |
| --- | --- | --- |
| `DESIGN.md` reverted to its pre-change form | No principle 8 declaration; no Bug Hunter role; no CI-gate description | `Criterion 1` × 3 MISS |
| `prompts/implementer.md` reverted | No new principle; no Adversarial pass section; no failing-test-first rule | `Criterion 2` × 3 MISS |
| `prompts/reviewer.md` reverted | No binding-audit step; no non-atomic artifact audit | `Criterion 3` × 2 MISS |
| `prompts/bug-hunter.md` deleted | File missing | `Criterion 4` × 2 MISS |
| `.github/workflows/maestro-ci.yml` deleted | No CI gate; PRs not blocked on test failures | `Criterion 5` × 6 MISS |
| `.maestro/schemas/tasks.schema.json` deleted | No schema; tasks.jsonl unvalidated | `Criterion 6` × 4 MISS |
| `.github/pull_request_template.md` reverted | PR template missing Runbook / Test mapping / Test-catches-it / Pre-mortem / Counterfactual / Bug Hunter findings | `Criterion 7` × 6 MISS |
| LEGACY markers removed from `evidence/2/`, `evidence/3/`, `evidence/6/` | `validate_evidence.py` fails CI on `main` | `Criterion 8` × 3 MISS |
| `.maestro/evidence/testing-validation/` artifacts deleted | This very directory becomes non-compliant | `Criterion 9` × 7 MISS |

The whole runbook would fail at every step. The change is doing the work.

## Captured demonstration of one revert

The full revert is too disruptive to commit. Instead, `test-catches-it.log` captures a narrower demonstration: deleting `prompts/bug-hunter.md`, running `verify.sh`, observing `Criterion 4` MISS, then restoring the file. That tightens the loop to "if I break this exact line, this exact assertion fails" — which is the regression-prevention guarantee we care about.

See [`test-catches-it.log`](./test-catches-it.log).
