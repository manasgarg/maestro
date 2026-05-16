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

## Install Maestro on another repo

Maestro can run the same loop in any of your other repos. The repo becomes a "satellite" pinned to a Maestro version; it always uses that version's prompts and workflows. You get a "bump to vN" PR in the satellite whenever a new Maestro version ships.

To install:

1. Copy [`tools/maestro-install-workflow.yml`](./tools/maestro-install-workflow.yml) into your target repo as `.github/workflows/maestro-install.yml`. Commit and push.
2. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret to the target repo (same one-step `/install-github-app` flow as above).
3. Go to Actions → "Maestro Install" → Run workflow. Pick a Maestro version (a tag like `v0.1.0`, or `main` for the bleeding edge). Within a minute or two you get an "Install Maestro" PR in the target repo, and the four Maestro labels (`maestro:direction` etc.) are created automatically.
4. Review the PR diff. Merge it.
5. File a `maestro:direction` issue in the target repo. The loop runs.

**Already-mature repos:** if the target repo already had `pull_request_template.md`, `ISSUE_TEMPLATE/maestro-direction.md`, or any `.github/workflows/maestro-*.yml`, those files are replaced wholesale — Maestro's rollout is absolute. If you want to keep informal house rules from the prior structure, run `/maestro-intake` in a Claude Code session in that repo before merging the install PR (or close the PR and re-dispatch after intake — the install workflow auto-closes the previous install PR on each dispatch). Intake reads the existing artifacts and extracts durable conventions into local learnings (or queues them as candidate improvements to Maestro itself).

**Branch-protected `main`:** if your satellite enforces signed commits on every branch (some org-wide rule sets do), the install push will be rejected because the bot's commit is unsigned. The workflow surfaces a friendly error in that case; the workaround is to run `tools/install_satellite.py` locally and push the install branch yourself with your own signed commit.

**Re-dispatching:** running Maestro Install again with the same ref against an already-installed satellite is a no-op (with a clear notice). Use it to confirm the satellite is healthy or to re-create the labels if they were ever deleted.

## Safe on public repos

The workflows that consume your API key are gated on `author_association` and only run for the repo owner, members, or collaborators. Issues and comments from anyone else are visible but cannot trigger Maestro.

## History

Past directions and their receipts are recorded in [`.maestro/tasks.jsonl`](./.maestro/tasks.jsonl). Heavyweight evidence (screenshots, recordings) lives under `.maestro/evidence/<issue-number>/`.
