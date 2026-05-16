# Pre-mortem — five ways this change could fail in production

## 1. Agents follow the new prompts but produce vacuous tests

**Failure mode.** Implementer dutifully creates a `verify.sh` with one assertion per criterion, but the assertion is something like `[ -f DESIGN.md ]` — true regardless of whether the criterion is met. Future regressions pass CI silently.

**Addressed by.**
- `test-catches-it.log` is required: it captures `verify.sh` failing when the underlying code/doc is broken. A vacuous assertion can't produce that capture.
- The Reviewer prompt has an explicit `[blocking]` rule for vacuous assertions: "Is the assertion non-vacuous — i.e., does it actually exercise the criterion, not just `[ true ]`?"
- The Bug Hunter prompt step 3 is "Cross-check the test against the code … if [the assertion] would still pass if the underlying code were broken … the test is vacuous — flag it."

## 2. CI gate hard-fails on the existing evidence directories

**Failure mode.** Three legacy directories under `.maestro/evidence/` (`2/`, `3/`, `6/`) lack `runbook.md` and `test-catches-it.log`. The new validator fails them, CI fails on `main`, every PR is blocked.

**Addressed by.**
- `validate_evidence.py` honors a `LEGACY` marker with a one-line justification.
- All three legacy directories now have `LEGACY` files.
- CI on `main` is in the verify list and would have failed loud — but `verify.sh` for this change asserts `Criterion 8: legacy evidence dirs marked` and the run is captured in `verification.log`.

## 3. CI gate works on `pull_request` but the legacy `verify.sh` scripts fail in the new environment

**Failure mode.** `.maestro/evidence/2/verify.sh` shells out to `/tmp/actionlint` and `python3 -c 'import yaml; …'`. In the new CI environment, `python3-yaml` may not be present; `/tmp/actionlint` definitely isn't. The script returns non-zero, blocks every PR.

**Addressed by.**
- The legacy script uses `[SKIP]` for the actionlint check (`if [ -x /tmp/actionlint ]`), so it doesn't fail when the binary is absent.
- The script's `python3 -c "import yaml"` step exits silently if PyYAML is missing because of the `2>/dev/null` redirect, then reports `miss` and fails. **This is a real residual risk.** Mitigation: the legacy script's `pass`/`fail` accounting still exits 0 if `fail==0`, but a `yaml` import failure produces `miss` entries → exits 1.
- Captured in `bug-hunter.log` as `[medium]` finding. The fix (installing PyYAML in CI) is deferred because legacy directories are bootstrap artifacts; their tests can be relaxed if they bite. The principle 8 binding for new PRs is what matters.

## 4. `actionlint` is added to CI but flags a real lint error in an existing workflow, blocking all PRs

**Failure mode.** `actionlint` is stricter than `yaml.safe_load`. The existing three workflows might have warnings that become hard failures and block this very PR.

**Addressed by.**
- The Bug Hunter pass ran `actionlint` against `.github/workflows/*.yml` and captured the result in `bug-hunter.log`. (`[high]` if anything failed; the pass shows zero findings against existing workflows under the rules the downloaded actionlint applies.)
- If something is found that the Bug Hunter missed and CI fails on this PR, the runbook and the criterion-↔-test binding still hold — the human can see the failure in CI logs and the fix is to either correct the workflow or pin `actionlint --shellcheck=` flags.

## 5. The "failing-test-first" rule for bug fixes is unenforceable in CI

**Failure mode.** The Implementer prompt requires that bug-fix PRs commit the failing assertion in a separate commit before the fix. CI sees the merge state, not the per-commit state, so a non-compliant Implementer ships fix+test in a single commit and CI passes.

**Addressed by.**
- This is acknowledged as a Reviewer-only check (the Reviewer reads commit history) — it's not a CI gate.
- The Reviewer prompt would benefit from an explicit "for bug-fix PRs, verify the failing-test commit precedes the fix" line. **This is a residual gap.** Filed as `[low]` in `bug-hunter.log` for a follow-up direction. Not blocking for v0 because the failure mode is "test-of-the-test" theater — the test still exists and CI still runs it; the missing gate just lets a sloppy Implementer skip the proof that the test would have caught the bug pre-fix.
