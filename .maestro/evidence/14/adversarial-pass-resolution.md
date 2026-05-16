# Adversarial pass — resolution

Resolutions for each finding in `adversarial-review.md`. Findings 1, 2, and 3 were fixed in the same commit as the rest of PR 1; the original captured review is preserved verbatim.

## Finding 1 (bug) — `maestro-implement.yml` job-gate silently skips satellite callers from non-issue/PR events

**Fixed.** Added `inputs.maestro_ref != '' ||` as the first OR-branch of the job-level `if:` in `.github/workflows/maestro-implement.yml`. Rationale documented in the surrounding workflow comment:

> The satellite shim is the satellite owner's code, secrets are inherited explicitly, and the satellite is responsible for gating its own caller event (typically with the same author_association check on whatever trigger fires the shim).

The trust model: when a satellite invokes Maestro via `workflow_call`, the satellite owns the gate. Maestro doesn't second-guess it — the satellite's shim is the satellite owner's code, and `secrets: inherit` is an explicit opt-in. PR 2's install scaffold will produce shims that include the same author_association check for their own caller events.

A new test (`tests/test_reusable_workflows.sh` section 6) locks this in so a future regression that drops the OR-branch fails CI.

## Finding 2 (bug) — `maestro-review.yml` job-gate silently skips satellite callers from non-PR events

**Fixed.** Same shape as Finding 1: added `inputs.maestro_ref != '' ||` to the job-level `if:` in `.github/workflows/maestro-review.yml`, with the same trust-model rationale documented inline. The same test section 6 covers this.

## Finding 3 (risk) — Prompts reference Maestro spec paths relatively; in satellite mode they resolve in the satellite's tree where the files don't exist

**Fixed.** The prompt-composition step in each of the three agent-running workflows now emits an explicit, forceful `## Path redirection (satellite mode — binding)` block whenever `PROMPTS_DIR != "."` (i.e., whenever we're in satellite mode). The block enumerates the specific paths each prompt references (`DESIGN.md`, `prompts/adversarial-reviewer.md`, `tools/build_learnings_index.py`, etc.) and maps each to `$PROMPTS_DIR/<that-path>`. It also reaffirms that the working directory is the satellite — that is where edits and commits land — and the Maestro checkout is read-only context.

The replacement is in:
- `.github/workflows/maestro-implement.yml` (covers `DESIGN.md`, `prompts/adversarial-reviewer.md`, `prompts/implementer.md`, `tools/build_learnings_index.py`)
- `.github/workflows/maestro-review.yml` (covers `DESIGN.md`, `prompts/reviewer.md`)
- `.github/workflows/maestro-learn.yml` (covers `DESIGN.md`, `tools/build_learnings_index.py`, `prompts/synthesizer.md`)

Test section 7 greps for the literal "Path redirection (satellite mode — binding)" header in all three workflows, so a future regression that drops it fails CI.

Follow-up worth doing later (not blocking this PR): templatize the prompt source itself so each Maestro spec path inside `prompts/*.md` is a `$MAESTRO_SRC/...` placeholder substituted at compose time. The current approach (forceful instruction in the wrapper) is correct in practice and avoids a prompt-rewrite churn before satellites even exist, but the templated form would close the gap more structurally.
