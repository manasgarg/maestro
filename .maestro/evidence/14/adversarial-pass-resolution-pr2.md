# Adversarial pass — resolution (PR 2)

Resolutions for each finding in `adversarial-review-pr2.md`. The captured review is preserved verbatim.

## Finding 1 (bug) — `git symbolic-ref refs/remotes/origin/HEAD` fails with `actions/checkout@v4`

**Fixed.** Dropped the `--base` flag from `gh pr create` in `tools/maestro-install-workflow.yml`. `gh pr create` defaults `--base` to the repo's default branch when not specified, which is what we want. Test section 6c locks the regression (asserts the workflow no longer uses `git symbolic-ref refs/remotes/origin/HEAD` to resolve `--base`).

## Finding 2 (bug) — README references a "Maestro Bootstrap" workflow the install doesn't deliver

**Fixed.** Added a `Create the four Maestro labels` step to `tools/maestro-install-workflow.yml`. It uses `actions/github-script@v7` to create the four labels directly in the satellite (idempotent — treats 422 "already exists" as OK). Updated `README.md` to drop the step that pointed at "Maestro Bootstrap" — installation is now one merge of the install PR. Test section 6a locks the regression (asserts each of the four label names appears in the install workflow).

## Finding 3 (bug) — Re-dispatch on an already-installed satellite aborts on `git commit nothing to commit`

**Fixed.** Added a `Detect no-op (already pinned to this ref)` step in `tools/maestro-install-workflow.yml`. It stages everything and asks `git diff --cached --quiet`; if no changes, it sets `steps.noop.outputs.is_noop=true`. The PR-creation and close-superseded steps then skip on `is_noop=true`. The label-creation step always runs, so re-dispatch is also a way to re-create labels if they're ever deleted. A friendly `::notice::` is emitted when no-op. Test section 6b locks the regression.

## Finding 4 — Self-withdrawn by the reviewer (not a bug)

No action needed.

## Finding 5 (risk) — Repeated dispatches accumulate stale install PRs

**Fixed.** Added a `Close any superseded install PRs` step in `tools/maestro-install-workflow.yml` that closes every open `maestro/install-*` PR before opening the new one (and deletes the branch via `gh pr close --delete-branch`). The close comment explains why ("Superseded by a newer Maestro Install dispatch"). This means: dispatching N times produces only the latest in-flight install PR, never N concurrent ones.

## Finding 6 (risk) — Branch-protection rules requiring signed commits would reject the bot's push

**Fixed.** Wrapped the `git push` in a check that greps the push log for `protected branch|signature required|signed commits`; on match, surfaces a `::error::` with a clear hint (run `tools/install_satellite.py` locally and push with your own signed commit). Documented the prerequisite in the README's "Install Maestro on another repo" section under **Branch-protected `main`**.

## Finding 7 (risk) — `/maestro-intake` commits directly to whatever branch is checked out, including `main`

**Fixed.** Added a `## Before you write anything: branch guard` section to `prompts/intake.md`. It instructs the agent to check `git symbolic-ref --short HEAD` against the repo's default branch and, on match, ask the human a tight observable question before creating `maestro-intake-<date>` and switching to it. Test section 7 locks the regression (asserts the prompt contains either "branch guard" or "default branch").

## Finding 8 (risk) — `/tmp/install-plan.txt` not preserved across step boundaries on hardened runners

**Fixed.** Switched all temp files in `tools/maestro-install-workflow.yml` to `$RUNNER_TEMP` (install plan, PR body, push log). `$RUNNER_TEMP` is GitHub's documented per-job temp directory and survives step boundaries on every runner type.

## Finding 9 (smell) — Tests use brittle `grep -E` checks on YAML structure

**Deliberately not addressed.** The tests are intentionally lightweight grep checks rather than full YAML parsers. Adding a `yq`/`yaml.safe_load` dependency to the test suite would buy stronger semantic guarantees but at the cost of a non-stdlib dependency for what is currently a shell-only test surface. Worth revisiting if the test surface grows beyond structural greps.

## Finding 10 (smell) — `is_mature` only checks the seven specifically-managed files, not the `maestro-*` glob

**Deliberately not addressed.** Intentional design: Maestro takes responsibility for exactly the files in `MAESTRO_MANAGED`. A satellite-owned `maestro-housekeeping.yml` outside that list belongs to the satellite, not to Maestro, and Maestro doesn't have authority to replace it. The `maestro-*` prefix is not formally reserved; if a future direction calls for that, the change is one constant in `install_satellite.py`.

Codex-style review surface for PR 2 — adversarial pass thread: `.maestro/evidence/14/adversarial-review-pr2.md`.
