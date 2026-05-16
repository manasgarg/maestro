# Adversarial review of #14 — PR 2 (satellite install machinery)

## Findings

1. **bug**: The install workflow always opens a PR with `--base "$(git symbolic-ref refs/remotes/origin/HEAD ...)"`, but `actions/checkout@v4` does not configure `refs/remotes/origin/HEAD`.
   - Location: `tools/maestro-install-workflow.yml:115`
   - What's wrong: `actions/checkout@v4` uses `git init`+`git fetch`, not `git clone`, so the `origin/HEAD` symbolic-ref is never created. `git symbolic-ref refs/remotes/origin/HEAD` exits non-zero with `fatal: ref refs/remotes/origin/HEAD is not a symbolic ref`. Under `set -eu`, the surrounding `gh pr create` call dies before it ever runs — the user sees the "Open the install PR" step fail with no PR created, despite the branch already being pushed.
   - User-observable consequence: the entire happy path documented in the README ("Within a minute or two you get an 'Install Maestro' PR in the target repo") fails on every fresh satellite. The human has to either rerun manually or discover the orphan branch and open the PR by hand.
   - Suggested fix: drop the `--base` flag entirely (gh defaults to the repo's default branch), or resolve the default branch via `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

2. **bug**: The README's post-merge instructions reference a "Maestro Bootstrap" workflow that the satellite install never delivers.
   - Location: `README.md:39` (step 5) and `tools/maestro-install-workflow.yml:104` (PR body)
   - What's wrong: `MAESTRO_MANAGED` in `tools/install_satellite.py` lists seven files; `maestro-bootstrap.yml` is not among them, and the `tools/satellite-template/.github/workflows/` directory contains only four shims (implement/review/ci/learn). After merging the install PR, the human goes to the Actions tab looking for "Maestro Bootstrap" and finds nothing. The four required labels (`maestro:direction` etc.) are never created, so filing a `maestro:direction` issue does not trigger the Implementer (the `if:` gate checks `github.event.label.name == 'maestro:direction'` — no label, no run).
   - User-observable consequence: install completes; loop is silently dead until the human realizes they need to create the four labels manually or copy in a bootstrap workflow that PR 2 doesn't ship.
   - Suggested fix: either add `maestro-bootstrap.yml` to the satellite template and `MAESTRO_MANAGED`, or have the install workflow create the labels directly (the satellite's `GITHUB_TOKEN` already has `issues: write` if granted) and update the README to drop step 5.

3. **bug**: Re-running "Maestro Install" with the same ref against an already-installed satellite aborts under `set -eu` because `git commit` exits non-zero on an empty tree.
   - Location: `tools/maestro-install-workflow.yml:73-76`
   - What's wrong: `install_satellite.py` is idempotent — running it with the same `--version` writes the same byte-for-byte content. After the first install merges, dispatching the install again to the same ref produces zero changes, `git commit -m ...` exits 1 (`nothing to commit, working tree clean`), and `set -eu` kills the job before the branch is pushed or the PR is opened. The human gets a red workflow with no explanation that it was a no-op.
   - User-observable consequence: humans who want to dispatch install to confirm the satellite is healthy, or who hit the workflow by accident, see a failure email instead of a "nothing to do" outcome.
   - Suggested fix: detect an empty diff (`git diff --cached --quiet || git commit ...`) and exit 0 with a clear "satellite already pinned to <ref>; nothing to do" message.

4. **bug**: `test_install_satellite_fresh.sh` invokes the script with `--source "$repo_root/tools/satellite-template"`, but `install_satellite.py`'s argparse has no `--source` argument.
   - Location: `tests/test_install_satellite_fresh.sh:18`, `tests/test_install_satellite_mature.sh:21,40`, vs. `tools/install_satellite.py:127-141`
   - What's wrong: Wait — re-reading, `install_satellite.py` does define `--source` (line 117 in the diff: `parser.add_argument("--source", ...)`). Cross-check ok. Withdrawn — not a bug. (Leaving this entry so the auditor sees I checked.)

5. **risk**: The install workflow has no guard against an open "Install Maestro" PR already existing on the satellite, so repeated dispatches accumulate stale install branches.
   - Location: `tools/maestro-install-workflow.yml:64-117`
   - What's wrong: Each dispatch creates `maestro/install-<ref>-<timestamp>` and opens a fresh PR. If the human dispatches twice (e.g. because finding #1 above made the first run look broken), they get N parallel install PRs and N abandoned branches. The PR body even instructs them to *close the PR and re-run* in the mature-repo escape hatch (`tools/maestro-install-workflow.yml:89`), which guarantees they will accumulate at least one stale branch.
   - User-observable consequence: dashboard clutter, ambiguous "which install PR is the real one?" question for the human, and possible merge of a stale one if the human picks wrong.
   - Suggested fix: `gh pr list --head "maestro/install-*" --state open` first; if any exist, close them (or refuse to dispatch with a clear message). At minimum, delete the stale branch when the PR is closed.

6. **risk**: The install push fails silently against any satellite whose `main` branch has protection rules requiring PR review or signed commits — but the workflow already pushed a *branch*, not to `main`, so this is only a problem if branch protection covers the install branch namespace.
   - Location: `tools/maestro-install-workflow.yml:76`
   - What's wrong: Many repos apply `*` or `release/*` rule sets that require signed commits on *all* branches. The bot's commit is unsigned. `git push` would be rejected by the server with a `protected branch` error.
   - User-observable consequence: install fails on hardened satellites with a cryptic git error. There's no documentation saying "ensure your branch protection allows `maestro/*` branches".
   - Suggested fix: document the prerequisite in the README and have the workflow surface a friendly error when push is rejected (e.g. trap the push failure and `echo "Push rejected — does your branch protection allow unsigned commits on maestro/install-*?"`).

7. **risk**: `prompts/intake.md` tells the agent to "commit on the current branch with message `learning: <slug>`", but does not require the agent to *create* a branch first.
   - Location: `prompts/intake.md:53,55` and `.claude/commands/maestro-intake.md:9`
   - What's wrong: If the human runs `/maestro-intake` from their default checkout, "current branch" is whatever they had checked out — frequently `main`. The agent will happily commit learnings directly to `main`, bypassing whatever review process the satellite normally enforces. This is doubly ironic in a prompt whose purpose is to *capture* the satellite's review conventions.
   - User-observable consequence: direct-to-main commits in a repo that may forbid them (or worse, in a repo whose convention is "every change goes through PR review"). On a protected `main` the commit fails after the work is done; on an unprotected `main` it silently violates the repo's norms.
   - Suggested fix: add a step: "Before writing the first learning, if HEAD is the default branch, ask the human for a branch name (default `maestro-intake-<date>`) and `git checkout -b` it."

8. **risk**: The Plan and Install steps in the install workflow run the script in two separate processes between which the satellite's working tree is unchanged — fine — but `/tmp/install-plan.txt` is captured from the Plan step and then re-read by the PR-body step *across job step boundaries*. If a runner garbage-collected `/tmp` between steps, the body would embed nothing. This is theoretically possible on self-hosted runners.
   - Location: `tools/maestro-install-workflow.yml:46-53` (writes) vs. `tools/maestro-install-workflow.yml:94` (reads)
   - What's wrong: On stock ubuntu-latest, `/tmp` survives across steps in the same job, so this is fine in practice. On hardened/self-hosted runners that mount `/tmp` per-step, the plan file would be missing and `$(cat /tmp/install-plan.txt)` would expand to empty under `set -eu` (cat itself exits non-zero, but it's inside `$(...)` in a heredoc so the exit code is swallowed — the body just contains an empty plan).
   - User-observable consequence: on non-default runners, the install PR body has an empty plan block — confusing but not data-destructive.
   - Suggested fix: write the plan to `$GITHUB_WORKSPACE/.install-plan.txt` (lives inside the checkout) or use `$RUNNER_TEMP`.

9. **smell**: `test_satellite_template.sh` checks `secrets: inherit` on three shims but not `maestro-ci.yml`. The diff's commentary in the CI shim says it "doesn't need a maestro_ref input"; consistent. But the same test does require an `^  issues:` and `^  issue_comment:` trigger on the implementer shim using `grep -Eq '^  '` (two spaces) — which is brittle to formatting and would silently start passing if those triggers were ever moved under a different parent key with the same indentation. Not a current bug; flagging as a smell because the test gives weaker guarantees than its assertion text claims.
   - Location: `tests/test_satellite_template.sh:64-77`
   - Suggested fix: parse with `yq` (or a one-line python `yaml.safe_load`) instead of `grep -E` to actually validate trigger semantics.

10. **smell**: The install script's `is_mature()` only counts files Maestro itself manages. If a satellite has a non-Maestro `.github/workflows/maestro-housekeeping.yml` (any file named `maestro-*` but not in `MAESTRO_MANAGED`), it won't trigger the "mature" warning, won't be replaced, and will silently coexist with the new Maestro workflows — possibly triggering on the same events. Likely intentional per the absolute-rollout-for-managed-files principle, but worth confirming.
    - Location: `tools/install_satellite.py:91-93` and `MAESTRO_MANAGED:42-50`
    - User-observable consequence: a satellite with a prior file like `.github/workflows/maestro-cleanup.yml` keeps it post-install; depending on what it does, that workflow may now race with or shadow the Maestro shims.
    - Suggested fix: needs Implementer judgement — either glob `.github/workflows/maestro-*.yml` for the mature check, or document that `maestro-*` is a reserved prefix.

Diff was 1125 lines across 18 files. Areas I looked hardest at: the install workflow's git/gh sequencing (findings 1, 3, 5), the satellite template's completeness vs. the README's post-install instructions (finding 2), and the intake prompt's branch handling (finding 7).
