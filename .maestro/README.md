# `.maestro/`

Runtime state for Maestro, committed to the repo so history is durable.

## `tasks.jsonl`

One line per completed (or abandoned) direction. Schema in [`schemas/tasks.schema.json`](./schemas/tasks.schema.json). Validated by the CI gate.

```json
{"issue": 42, "title": "...", "completed_at": "2026-05-15T18:00:00Z", "prs": [43, 44], "summary": "<observable change>"}
```

Append-only. Failed attempts are recorded with `"status": "abandoned"` and a `"reason"` field.

## `schemas/`

JSON Schemas for the structured artifacts under `.maestro/`. Validated by `scripts/` and run by the CI gate.

## `scripts/`

Validation scripts used by the CI gate (`.github/workflows/maestro-ci.yml`):

- `validate_tasks_jsonl.py` — every row of `tasks.jsonl` conforms to `schemas/tasks.schema.json`.
- `validate_evidence.py` — every `evidence/<dir>/` has the required artifacts (per DESIGN.md principle 8).

## `evidence/<issue-or-pr>/`

Per-PR evidence. Every directory contains (DESIGN.md principle 8):

| File | Required when | What it is |
| --- | --- | --- |
| `verify.sh` | always | The automated test — one named assertion per acceptance criterion. CI runs this on every PR. |
| `runbook.md` | always | Narrated demo. Numbered steps a non-coder can read; each step cites the captured artifact. |
| `verification.log` | always | Captured output of `verify.sh`. |
| `test-catches-it.log` | always | Captured proof the assertions fail when the underlying code is broken. |
| `pre-mortem.md` | non-atomic direction | At least five named failure modes the Implementer addressed. |
| `counterfactual.md` | non-atomic direction | Runbook re-executed with the change reverted, captured as failing. |
| `bug-hunter.log` | non-atomic direction | Output of the Bug Hunter adversarial pass. |
| `NON_ATOMIC` | non-atomic direction | Marker file (zero-byte or one-line). Tells `validate_evidence.py` to require the extras above. |
| `LEGACY` | predates principle 8 | Opt-out marker with a one-line justification. CI warns but does not fail. |

Heavy artifacts (screenshots, recordings, perf reports) live in the same directory and are cited from `runbook.md`.
