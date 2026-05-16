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

**Your own test runner:** if your repo already has `tools/run_tests.sh`, install leaves it alone — your runner wins. If not, install writes Maestro's default one (which discovers executable files under `tests/test_*` and exits 0 cleanly when there are no tests yet, so fresh satellites get a green CI immediately).

**Branch-protected `main`:** if your satellite enforces signed commits on every branch (some org-wide rule sets do), the install push will be rejected because the bot's commit is unsigned. The workflow surfaces a friendly error in that case; the workaround is to run `tools/install_satellite.py` locally and push the install branch yourself with your own signed commit.

**Re-dispatching:** running Maestro Install again with the same ref against an already-installed satellite is a no-op (with a clear notice). Use it to confirm the satellite is healthy or to re-create the labels if they were ever deleted.

## Keep satellites bumped automatically

Once you have one or more satellites installed, register them in [`satellites.txt`](./satellites.txt) (one `owner/repo` per line). Push a new Maestro tag (anything matching `v*` — typically a semver release like `v0.2.0`), and within a few minutes the rollout workflow opens a "Bump Maestro to v0.2.0" PR in every registered satellite. Merge each one when you're ready; satellites can sit on different versions indefinitely.

One-time PAT setup (the workflow's built-in `GITHUB_TOKEN` can't write to another repo, so the rollout uses a PAT instead):

1. Create a fine-grained Personal Access Token at GitHub → Settings → Developer settings → Fine-grained tokens → "Generate new token". Scope it to every registered satellite with the permissions `Contents: Read and write` and `Pull requests: Read and write`. (Or use a classic PAT with the `repo` scope if you prefer.)
2. Add the token as a Maestro repo secret named `MAESTRO_ROLLOUT_PAT`.

You can also dispatch the rollout manually from Maestro's Actions tab — use the `ref` input to bump to any tag, branch, or sha, and `dry_run: true` to preview the plan without opening PRs. Each satellite's previous open bump PR is closed automatically when the next rollout supersedes it, so you never end up with two competing bump PRs in the same satellite.

## Receive upstream learnings from satellites

The reverse of the bump flow: when a Maestro session inside a satellite produces a learning that's about the *Maestro process itself* (workflows, agent prompts, evidence conventions, GitHub event quirks) rather than the satellite's own domain, the synthesizer routes it back to Maestro as a PR titled "Upstream learning: \<slug\>". You review and merge as usual; the learning ships in the next Maestro release tag and rolls back out to every satellite on bump.

Two paths produce upstream PRs:

- **Interactive.** Running `/learn` or `/maestro-intake` in a Claude Code session inside a satellite. Auth uses your personal `gh auth login` — no extra setup; the PR shows up authored by you.
- **Scheduled.** The satellite's daily Maestro Learn workflow (cron). Auth uses a satellite-side PAT secret named `MAESTRO_UPSTREAM_PAT` — create a fine-grained PAT scoped to `manasgarg/maestro` with `Contents: Read and write` and `Pull requests: Read and write`, and add it to each satellite that should be allowed to PR upstream. Without the secret, the scheduled run just skips workflow-level candidates with a notice (your next interactive `/learn` can route them).

You don't need to do anything on the Maestro side — incoming PRs land on `main` like any other PR, with a body explaining which satellite extracted the learning and why the synthesizer thought it was workflow-level (not repo-specific). Close the PR if you disagree with the classification.

## Safe on public repos

The workflows that consume your API key are gated on `author_association` and only run for the repo owner, members, or collaborators. Issues and comments from anyone else are visible but cannot trigger Maestro.

## History

Past directions and their receipts are recorded in [`.maestro/tasks.jsonl`](./.maestro/tasks.jsonl). Heavyweight evidence (screenshots, recordings) lives under `.maestro/evidence/<issue-number>/`.
