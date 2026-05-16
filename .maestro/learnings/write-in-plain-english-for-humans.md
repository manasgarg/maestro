---
source: Claude Code session on branch claude/implement-issue-14-tJcOF, after opening PR #15 (https://github.com/manasgarg/maestro/pull/15) with a description heavy on GitHub Actions jargon — see issue #14 thread and the rewritten PR body for the recipe.
date: 2026-05-16
tags: [writing-style, communication, maestro]
---

Write in plain English on every surface a human reads — proposals, PR descriptions, issue comments, receipts, commit messages, session replies. Lead with what changes and why, in language a person who hasn't been in the build with you can follow. Push framework names (`workflow_call`, `secrets: inherit`, conditional checkouts, OR-branches, etc.) into the bottom of the relevant sections or into the diff itself, not into the explanatory prose.

The reader isn't reviewing your work in their head while they read; they're trying to figure out whether this change is the change they wanted. Names of mechanisms only help readers who already know what each mechanism does. Observable consequences ("you won't see anything different in this repo until PR 2 lands") help everyone. "Be concise" alone (as the Implementer prompt says) is necessary but not sufficient — concise jargon is still jargon. The recipe is: name the change, name the consequence, then add the technical detail at the end of the section for the reader who wants it.

This does not apply inside code, prompts, workflow files, or tests. Those have other readers — future agents and future you — and benefit from precise technical terms.
