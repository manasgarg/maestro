---
source: https://github.com/manasgarg/maestro/pull/2
date: 2026-05-15
tags: [maestro, evidence]
---

When producing evidence for a Maestro PR, commit a `verify.sh` and its captured `verification.log` under `.maestro/evidence/<issue-number>/` rather than embedding the run output in the PR description. The script gives the reviewer (human or AI) a re-runnable artifact; the log gives them the captured proof without forcing them to set up dependencies.

Structure each check in `verify.sh` so its line of output in `verification.log` reads as a pass/fail line tied to a specific acceptance criterion. The PR description's "Evidence" section cites the captured log lines by criterion number, not the script invocation. This way: the diff shows what the change is, the script shows how to re-verify, and the log shows it was verified — with the reviewer's only required step being to read.

Flag criteria you cannot self-verify on the runner (e.g. those needing a live `CLAUDE_CODE_OAUTH_TOKEN` or external dependencies) explicitly in the PR's Evidence section with the reason. Do not silently omit them.
