# Maestro

An AI-driven dev workflow orchestrator. You file direction; AI does the implementation. Both you and AI agents provide direction and feedback. Read [`DESIGN.md`](./DESIGN.md) for the principles and full lifecycle.

## File a direction

Open a new issue. Title it with what you want. Body can be any granularity, from "fix this typo" to "ship a billing system." Add the `maestro:direction` label.

Maestro's Implementer will reply within ~5 minutes with a proposal: decomposition into atomic changes, observable acceptance criteria, and any clarifying questions phrased in terms you can directly see or measure.

## What you'll see

- **A proposal** as a comment on your issue.
- **Clarifying questions** if needed — answer by commenting; the `maestro:awaiting-human` label tracks when you're blocking.
- **Pull requests** linked to your issue, one per atomic change. Each PR shows what observable change it makes and the evidence.
- **AI review** on each PR within ~5 minutes — advisory only, you decide what merges.
- **A receipt** on your original issue when the work is done: observable change + evidence.

## Approving a proposal

Reply on the issue with a positive comment — "go", "approved", "lgtm", "ship it", or similar. A 👍 reaction alone does not trigger Maestro (GitHub Actions does not fire workflow runs on reactions); the implementer needs a comment to read.

## Setup (one-time)

Maestro uses your existing Claude Code subscription via an OAuth token — no separate API billing.

1. **Install the Claude GitHub App and provision the secret in one step.** Open Claude Code in any directory and run the slash command `/install-github-app`. It walks you through installing the GitHub App on this repo and writes the `CLAUDE_CODE_OAUTH_TOKEN` secret for you. You need admin access to the repo.
2. **Run the Maestro bootstrap workflow.** Actions tab → "Maestro Bootstrap" → Run workflow. This creates the four labels Maestro uses.

After that, file a `maestro:direction` issue and the loop runs.

## Safe on public repos

The workflows that consume your API key are gated on `author_association` and only run for the repo owner, members, or collaborators. Issues and comments from anyone else are visible but cannot trigger Maestro.

## History

Past directions and their receipts are recorded in [`.maestro/tasks.jsonl`](./.maestro/tasks.jsonl). Heavyweight evidence (screenshots, recordings) lives under `.maestro/evidence/<issue-number>/`.
