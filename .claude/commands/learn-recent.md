---
description: Synthesize learnings across recent sessions, issues, and PRs in one pass
---

You are now in synthesizer mode for this repo (Maestro). Your role is defined in `prompts/synthesizer.md` — read it.

## This invocation

- **Mode:** D (on-demand cross-surface)
- **Window:** by default, the last 24 hours. If the user typed an argument after `/learn-recent` (e.g. `/learn-recent 7d` or `/learn-recent 48h`), parse that as the window. Accept suffixes `h` (hours), `d` (days). On parse failure, default to 24h and tell the user.

## Sources to scan

Synthesize from **all three** in one pass:

1. **Local Claude Code session transcripts for this repo.** Look under `~/.claude/projects/`. Claude Code encodes the project path into directory names — find the directory whose name corresponds to this repo's path (typically the absolute path with `/` replaced by `-`). Inside, every `*.jsonl` file is a transcript. Read each whose modification time is within the window.

2. **Issues closed in the window.** Use the GitHub MCP tools. Apply the trusted-actor filter from the Security section of `prompts/synthesizer.md` — only read content from `OWNER`, `MEMBER`, or `COLLABORATOR`. Filter comments by author too.

3. **PRs merged in the window.** Use GitHub MCP. Same trusted-actor filter.

## Synthesize

Read existing learnings with overlapping tags first. Skip duplicates; supersede refinements. The default is to skip.

For each learning you write, the `source:` is the single most specific source (a transcript path, an issue URL, or a PR URL) — not the union.

## After deciding

- **If you wrote one or more files:** regenerate the index (`python3 tools/build_learnings_index.py`), create branch `learnings/<YYYY-MM-DD-HHMMSS>` from current `main`, add the new learning files + the regenerated `INDEX.md` (do not touch `.last-synthesized-at` — Mode D leaves the scheduled-batch state alone), commit, push, and open a PR titled `learnings: <window-end-YYYY-MM-DD>`. The PR body groups each learning under its source surface (Session / Issue / PR).
- **If you skip:** print `SKIP: <one-line reason>` and stop. Do not commit anything.

## Be ruthless

The fastest way to make `.maestro/learnings/` worthless is to commit everything. The default is to skip. Re-read the "What is NOT a learning" section of `prompts/synthesizer.md` if you find yourself wanting to write something.
