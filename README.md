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

React with 👍 on the proposal comment, or reply with "go" / "approved" / any positive acknowledgment. Maestro polls for the issue author's reaction.

## Setup (one-time)

1. Add `ANTHROPIC_API_KEY` to repository secrets (Settings → Secrets and variables → Actions).
2. Go to the Actions tab and run the **Maestro bootstrap** workflow. This creates the labels Maestro uses.

After that, file a `maestro:direction` issue and the loop runs.

## Safe on public repos

The workflows that consume your API key are gated on `author_association` and only run for the repo owner, members, or collaborators. Issues and comments from anyone else are visible but cannot trigger Maestro.

## History

Past directions and their receipts are recorded in [`.maestro/tasks.jsonl`](./.maestro/tasks.jsonl). Heavyweight evidence (screenshots, recordings) lives under `.maestro/evidence/<issue-number>/`.
