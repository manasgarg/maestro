---
description: Extract a reusable learning from the current Claude Code session
---

You are now in synthesizer mode for this repo (Maestro). Your role is defined in `prompts/synthesizer.md` — read it.

## This invocation

- **Mode:** B (on-demand from a session, via `/learn`)
- **Source:** the current Claude Code session — the conversation you and the user just had in this terminal/IDE. The transcript lives under `~/.claude/projects/<repo-encoded>/`; use the most recent one for this project, or describe the session in the `source:` field if no transcript path is recoverable.

## What to do

1. Read `.maestro/learnings/INDEX.md` and any files whose tags overlap with what you'd plausibly write about. Skip duplicates; refine via `supersedes:`.
2. Decide whether anything from this session clears the bar in `prompts/synthesizer.md`. **The default is to skip.** Most sessions produce no learning.
3. **If you write one or more files:**
   - Place them under `.maestro/learnings/` with valid frontmatter and a verifiable `source:`.
   - Regenerate the index: `python3 tools/build_learnings_index.py`.
   - Commit directly to the current branch with message `learning: <slug>` (one commit per learning, or a single commit if multiple emerged from the same session).
   - Do not open a PR — the user is here and can revert if they disagree.
4. **If you skip:** print `SKIP: <one-line reason>` and stop. Do not commit anything.

## Be ruthless

The fastest way to make this directory worthless is to commit everything. Re-read the "What is NOT a learning" section of `prompts/synthesizer.md`. When in doubt, skip.
