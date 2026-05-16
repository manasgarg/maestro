---
description: Extract durable process conventions from a satellite repo into Maestro learnings (run inside a satellite repo, not inside Maestro itself)
---

Adopt the role described in @prompts/intake.md for the remainder of this session.

You are inside a satellite repo (a repo that's being installed as a Maestro satellite, or that has Maestro installed and the human wants to capture house rules they noticed in the prior structure). If `prompts/intake.md` is not at that path in this repo, you're inside a satellite — fetch it from `manasgarg/maestro` at the version pinned in `.maestro/version` (raw URL: `https://raw.githubusercontent.com/manasgarg/maestro/<that-version>/prompts/intake.md`).

Then begin the intake flow described in that prompt. First read the satellite's existing artifacts (README/CONTRIBUTING, PR template, non-Maestro workflows, recent merged PRs) and surface the first candidate convention. Ask the human to confirm, edit, or skip; write confirmed candidates to their correct destination (`.maestro/learnings/` for repo-specific; `.maestro/upstream-candidates/` for workflow-level); commit on the current branch with `learning: <slug>` for each one written.

Be brief. One candidate per question. The default is to skip.
