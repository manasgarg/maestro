# Adversarial pass — resolution

Resolutions for each finding in `adversarial-review.md`. Findings 1, 2, and 3 were fixed in the same commit as the rest of PR 1; the original captured review is preserved verbatim.

## Finding 1 (bug) — `maestro-implement.yml` job-gate silently skips satellite callers from non-issue/PR events

**Reverted on follow-up review.** I initially added `inputs.maestro_ref != '' ||` as the first OR-branch of the job-level `if:` to admit satellite callers from any caller event. ChatGPT Codex flagged the equivalent change in `maestro-review.yml` (see Finding 2 below) and the same critique applies here: the implementer's behavior is keyed off the triggering event (see the "Triggering events" section of `prompts/implementer.md`), so admitting calls from caller events that don't match `issues`/`issue_comment`/`pull_request` would just burn credits with no useful work to do.

**Final resolution: the satellite contract for `maestro-implement.yml` is event-shape-matched.** Satellite shims MUST trigger on the same event types Maestro itself does — `issues` (labeled), `issue_comment` (created), and `pull_request` (closed). Calls from any other caller event silently no-op by design. This is documented inline in the workflow's `if:` block, and `tests/test_reusable_workflows.sh` section 6 asserts the OR-branch is NOT present (a regression lock against a future agent re-adding the over-broad gate).

The original finding's framing was incorrect: silent-skip on non-matching satellite events is the correct behavior, not a bug.

## Finding 2 (bug) — `maestro-review.yml` job-gate silently skips satellite callers from non-PR events

**Reverted on follow-up review.** Same as Finding 1. ChatGPT Codex flagged the OR-branch on PR #15: when a satellite shim calls the reviewer from `workflow_dispatch` or any other non-`pull_request` event, `github.event.pull_request.*` is empty and the workflow declares no PR-number input. The compose step would render `pull request: # —`, the agent has no PR to review, and the job consumes credits with nothing to do.

**Final resolution: the satellite contract for `maestro-review.yml` is `pull_request`-only.** Satellite shims MUST trigger on `pull_request` events (`opened`/`synchronize`/`reopened`). Calls from any other caller event silently no-op by design. Documented inline in the workflow's `if:` block; locked in by the same test section 6 as Finding 1. If a future direction wants explicit "review PR N" calls from non-PR events, the right shape is to add a `pr_number` input to the reusable surface — not a permissive OR-branch.

Codex's review thread: https://github.com/manasgarg/maestro/pull/15#discussion_r3252362807

## Finding 3 (risk) — Prompts reference Maestro spec paths relatively; in satellite mode they resolve in the satellite's tree where the files don't exist

**Fixed.** The prompt-composition step in each of the three agent-running workflows now emits an explicit, forceful `## Path redirection (satellite mode — binding)` block whenever `PROMPTS_DIR != "."` (i.e., whenever we're in satellite mode). The block enumerates the specific paths each prompt references (`DESIGN.md`, `prompts/adversarial-reviewer.md`, `tools/build_learnings_index.py`, etc.) and maps each to `$PROMPTS_DIR/<that-path>`. It also reaffirms that the working directory is the satellite — that is where edits and commits land — and the Maestro checkout is read-only context.

The replacement is in:
- `.github/workflows/maestro-implement.yml` (covers `DESIGN.md`, `prompts/adversarial-reviewer.md`, `prompts/implementer.md`, `tools/build_learnings_index.py`)
- `.github/workflows/maestro-review.yml` (covers `DESIGN.md`, `prompts/reviewer.md`)
- `.github/workflows/maestro-learn.yml` (covers `DESIGN.md`, `tools/build_learnings_index.py`, `prompts/synthesizer.md`)

Test section 7 greps for the literal "Path redirection (satellite mode — binding)" header in all three workflows, so a future regression that drops it fails CI.

Follow-up worth doing later (not blocking this PR): templatize the prompt source itself so each Maestro spec path inside `prompts/*.md` is a `$MAESTRO_SRC/...` placeholder substituted at compose time. The current approach (forceful instruction in the wrapper) is correct in practice and avoids a prompt-rewrite churn before satellites even exist, but the templated form would close the gap more structurally.
