# `.maestro/`

Runtime state for Maestro, committed to the repo so history is durable.

## `tasks.jsonl`

One line per completed direction. Each line is JSON:

```json
{"issue": 42, "title": "...", "completed_at": "ISO-8601", "prs": [43, 44], "summary": "<observable change>"}
```

Append-only. Failed attempts are recorded with `"status": "abandoned"` and a `"reason"` field.

## `evidence/<issue-number>/`

Heavyweight evidence for a direction — screenshots, recordings, perf reports, sample outputs. Light evidence (test names, command output) lives directly in the PR/receipt comments.
