# Runbook — "Add testing & validation" change

Read top-to-bottom. Each step is something you can see in the repo without running any code. Where a step has a captured artifact, the path is in code font.

## What changed, observably

Maestro now binds every acceptance criterion to **three artifacts** — a runbook step, a named assertion in `verify.sh`, and a captured evidence file — and a **CI gate** enforces them on every PR. A new **Bug Hunter** sub-role does an adversarial pass on non-atomic direction before a PR opens.

## Step 1 — Read the new principle

Open [`DESIGN.md`](../../../DESIGN.md). Scroll to the *Principles* section. You will see seven principles you've seen before, plus a new **Principle 8** declaring the three-artifact binding, naming the CI gate, and pointing at the Bug Hunter sub-role.

> Captured grep: `verification.log` lines tagged `Criterion 1`.

## Step 2 — See the Bug Hunter role appear

In the same `DESIGN.md`, the *Roles* section now lists **Bug Hunter** as the fourth AI role (after Thinking Partner, Implementer, Reviewer). Open [`prompts/bug-hunter.md`](../../../prompts/bug-hunter.md) — that's the prompt the Implementer loads when invoking the adversarial pass.

> Captured grep: `verification.log` lines tagged `Criterion 4`.

## Step 3 — See the Implementer's new operating instructions

Open [`prompts/implementer.md`](../../../prompts/implementer.md). The *Principles* section now has **principle 8**, mirroring DESIGN.md. The *PR format* section has new required sections (Runbook, Test mapping, Test-catches-it, Pre-mortem, Counterfactual, Bug Hunter findings). At the end is an *Adversarial pass* section telling the Implementer to spawn the Bug Hunter for non-atomic direction.

> Captured grep: `verification.log` lines tagged `Criterion 2`.

## Step 4 — See the Reviewer's new audit checklist

Open [`prompts/reviewer.md`](../../../prompts/reviewer.md). The *What to review* section's primary item is now **Audit the criterion-↔-test-↔-evidence binding**, with explicit `[blocking]` triggers (missing assertion, vacuous assertion, missing test-catches-it.log, missing runbook step). For non-atomic direction, the Reviewer also audits `pre-mortem.md`, `counterfactual.md`, and `bug-hunter.log`.

> Captured grep: `verification.log` lines tagged `Criterion 3`.

## Step 5 — See the CI gate

Open [`.github/workflows/maestro-ci.yml`](../../../.github/workflows/maestro-ci.yml). It runs on every PR. The steps are:

1. `actionlint` over all workflows.
2. `python .maestro/scripts/validate_tasks_jsonl.py` — every `tasks.jsonl` row validates against `tasks.schema.json`.
3. `python .maestro/scripts/validate_evidence.py` — every evidence directory has the required artifacts.
4. Iterate `bash .maestro/evidence/*/verify.sh` — run every PR's named assertions. The job fails if any one returns non-zero.

Merge is blocked on this workflow failing. This is the only enforcement that does not rely on agent compliance.

> Captured grep: `verification.log` lines tagged `Criterion 5`.

## Step 6 — See the JSON schema for `tasks.jsonl`

Open [`.maestro/schemas/tasks.schema.json`](../../schemas/tasks.schema.json). It pins the row format (issue, title, ISO-8601 `completed_at`, prs, summary, optional status/reason with `abandoned` requiring `reason`). [`validate_tasks_jsonl.py`](../../scripts/validate_tasks_jsonl.py) is the validator CI runs.

> Captured grep: `verification.log` lines tagged `Criterion 6`.

## Step 7 — See the new PR template

Open [`.github/pull_request_template.md`](../../../.github/pull_request_template.md). New sections force the Implementer to cite the runbook, the test mapping, the test-catches-it log, and (for non-atomic PRs) the pre-mortem, counterfactual, and Bug Hunter outputs.

> Captured grep: `verification.log` lines tagged `Criterion 7`.

## Step 8 — See the legacy markers on old evidence dirs

`ls .maestro/evidence/` shows `2`, `3`, `6`, `testing-validation`. The first three predate principle 8 and each contains a `LEGACY` file with a one-line justification, which `validate_evidence.py` accepts as opt-out.

> Captured grep: `verification.log` lines tagged `Criterion 8`.

## Step 9 — This very directory complies

`ls .maestro/evidence/testing-validation/` shows the eight files principle 8 requires for non-atomic direction:

| File | Role |
| --- | --- |
| `verify.sh` | the automated test |
| `runbook.md` | this file |
| `verification.log` | captured `verify.sh` output |
| `test-catches-it.log` | captured proof the assertions aren't vacuous |
| `pre-mortem.md` | five named failure modes |
| `counterfactual.md` | runbook re-executed with the change reverted, failing |
| `bug-hunter.log` | adversarial-pass findings |
| `NON_ATOMIC` | marker file telling the validator to require the extras |

> Captured grep: `verification.log` lines tagged `Criterion 9`.

## To re-run

```
bash .maestro/evidence/testing-validation/verify.sh
```

That's the same command CI runs. Expect a passing summary at the end. Compare your local output to [`verification.log`](./verification.log).
