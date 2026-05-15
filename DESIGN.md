# Maestro

An AI-driven dev workflow orchestrator. Humans and AI agents both provide direction and feedback. AI does all the implementation work.

## How it works

Direction enters as a GitHub issue. An AI Implementer responds with a proposal that decomposes the direction into atomic changes, lists observable acceptance criteria, and asks any clarifying questions in terms the human can directly observe. Once the human approves (or answers), the Implementer opens one PR per atomic change. An AI Reviewer critiques each PR, focused on whether the evidence demonstrates the acceptance criteria. When the work merges, the Implementer posts a receipt on the original issue: what changed observably, and the evidence.

## Principles

These principles govern every Implementer and Reviewer action. They were set by the human and are not negotiable by the agents.

1. **Direction granularity is open.** A direction can be anything from "fix this typo" to "ship a billing system." The Implementer decomposes.

2. **Implementers lead with a proposal.** Before any code is written for non-atomic direction, the Implementer posts a proposal: decomposition, acceptance criteria, clarifying questions, tradeoffs. The proposal is the contract.

3. **Human-in-the-loop is minimized.** Humans are consulted to clarify desired outcomes, not to make implementation decisions. Engine choice, file layout, library selection, naming — these are the Implementer's call.

4. **Clarifying questions are observable-only.** Every question the Implementer asks must be answerable in terms of what the human can directly see, do, or measure. Internal technical forks are translated to their observable consequences before being asked, or made silently.

5. **AI feedback is advisory; human feedback is binding.** The Implementer considers Reviewer feedback and may override it (by replying with reasoning). The Implementer never overrides human feedback but may append tradeoff warnings.

6. **GitHub is the source of truth.** Directions are issues. Proposals are comments. Implementations are PRs. Reviews are PR comments. Receipts are issue comments. History is in the repo.

7. **Every change produces observable evidence — and the Implementer produces it.** Acceptance criteria and evidence share a vocabulary. The Implementer runs the verification themselves and records the run (script output, screenshots, captured commands, test logs, measurements) under `.maestro/evidence/<issue-number>/`. The PR's Evidence section cites the recorded artifact, not instructions the human must follow. A criterion the Implementer genuinely cannot verify must be flagged with the reason. Pure refactors produce evidence of no regression. Failed attempts also produce a receipt explaining what was tried and what was observed.

## Roles

- **Human.** Files direction at any granularity. Answers clarifying questions. Approves or redirects proposals. Reviews and merges PRs. Binding on all decisions.
- **Implementer.** AI agent. Reads direction, leads with a proposal, asks observable-only clarifying questions, decomposes into atomic tasks, opens PRs, addresses review feedback, produces receipts.
- **Reviewer.** AI agent. Critiques Implementer's PRs. Audits evidence against acceptance criteria. Advisory only.
- **Orchestrator.** Not an AI agent. GitHub Actions, triggered by labels and PR events, dispatch Implementers and Reviewers. Deterministic.

## Lifecycle

1. **Direction.** Human (or AI agent) files an issue with the `maestro:direction` label. AI-originated direction is additionally labeled `maestro:ai-proposed` and waits for one human 👍 before proceeding.
2. **Proposal.** Implementer posts a proposal as a comment on the issue, within ~5 minutes of the trigger.
3. **Questions (optional).** If the proposal includes clarifying questions, the issue is labeled `maestro:awaiting-human`. The label is removed when the human responds.
4. **Implementation.** Once the proposal is approved (a 👍 reaction or positive comment by the issue author), the Implementer opens one PR per atomic change. PR descriptions use the *Observable change / Evidence* format.
5. **Review.** Within ~5 minutes of a Maestro PR opening or updating, the Reviewer posts review comments. Advisory only.
6. **Merge.** The human merges (or asks for changes).
7. **Receipt.** When the last atomic PR for a direction closes its parent issue, the Implementer posts a closing receipt: observable change + evidence. The issue is labeled `maestro:done`. A summary row is appended to `.maestro/tasks.jsonl`.

## Edge-case defaults

- **Ambiguous atomic direction.** If a small direction has multiple plausible implementations with observably different results, the Implementer asks. If the difference would not be observable, the Implementer picks and discloses.
- **AI-originated direction.** Labeled `maestro:ai-proposed`. Never executes without one human acknowledgment.
- **Proposal rejection loop.** After two consecutive human-rejected revisions, the Implementer's next response must be a clarifying question.
- **Reviewer disagreement.** Surfaced to the human only when both views are blocking-severity. Otherwise the Implementer picks and proceeds.
- **Multi-PR direction.** Closes when the last sub-PR merges. The human can reopen with new direction at any time.

## Evidence model

Evidence demonstrates each acceptance criterion. Forms include:

- A test name and its pass status, when the criterion is verifiable by tests.
- Before/after measurements (latency, error rates, counts).
- Reproducible commands the human can re-run.
- Screenshots, recordings, or sample outputs, committed under `.maestro/evidence/<issue-number>/` for durability.
- A demo issue/PR walk-through, for system-level changes.

Pure refactors with no user-observable effect produce evidence of no regression: tests passing, golden flows still working.

Failed attempts produce a receipt explaining what was tried, what was observed, and why the work stopped.

## Setup

One-time per repo:

1. Set `ANTHROPIC_API_KEY` as a repository secret (Settings → Secrets and variables → Actions).
2. Run the **Maestro bootstrap** workflow from the Actions tab to create the labels.

After setup, file an issue with the `maestro:direction` label and the loop runs.

## Public-repo safety

Maestro is safe to run on public repositories. The workflows that consume `ANTHROPIC_API_KEY` are gated on `author_association` and only fire when the actor is `OWNER`, `MEMBER`, or `COLLABORATOR`. Issues, comments, and PRs from anyone else are visible but cannot trigger Maestro. GitHub additionally does not pass secrets to workflows triggered by fork pull requests.
