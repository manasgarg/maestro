---
source: https://github.com/manasgarg/maestro/issues/7
date: 2026-05-16
tags: [maestro, evidence]
supersedes: [maestro-evidence-as-rerunnable-script.md]
---

When producing evidence for a Maestro PR, commit a `verify.sh` (or `verify.py`) plus its captured `verification.log` under `.maestro/evidence/<issue-number>/`. Print one pass/fail line per acceptance criterion so the reviewer can grep the log by criterion number instead of reading the whole run.

The v1 of this learning prescribed the pattern. This refinement adds a constraint: when an artifact under `verify.sh` produces other captured artifacts (e.g. a transcript log, a before/after diff), put those in a subdirectory of the evidence dir and reference them from the main log by relative path. Reviewers (especially AI reviewers with limited context) skim the top-level log first and follow references; flat directories with a dozen sibling files force them to guess which file matters.

Refines: `maestro-evidence-as-rerunnable-script.md`.
