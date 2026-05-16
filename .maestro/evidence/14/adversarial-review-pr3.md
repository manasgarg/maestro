# Adversarial review of #14 — Maestro downstream rollout (PR 3)

## Findings

1. **bug**: `tr -d '[:space:]'` concatenates every satellite onto one line, so multi-satellite registries silently fail.
   - Location: `.github/workflows/maestro-rollout.yml:79`
   - What's wrong: The pipeline `grep -Ev '^\s*(#|$)' satellites.txt | tr -d '[:space:]' | grep .` strips *all* whitespace including the newlines between entries. With two satellites `owner1/repo1` and `owner2/repo2`, the resulting `satellites.list` contains a single line `owner1/repo1owner2/repo2`. `wc -l` then reports `count=1`, the loop iterates once over the garbled line, and `git clone https://github.com/owner1/repo1owner2/repo2.git` fails. Verified by running the exact pipe locally.
   - User-observable consequence: As soon as the registry contains 2+ satellites (the only configuration that actually exercises the "every satellite" promise of the feature), no satellite receives a bump PR. The failure is logged as a single per-satellite warning and the rollout job exits 0, so it looks like a successful rollout.
   - Suggested fix: Replace `tr -d '[:space:]'` with a per-line trim, e.g. `sed -E 's/[[:space:]]+//g'` is wrong for the same reason — use `awk '{gsub(/[[:space:]]+/,""); if ($0!="") print}'`, or simply `grep -Eo '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+'`.

2. **bug**: On manual dispatch with no `ref` input, the target ref resolves to `refs/heads/main` (or whatever branch the workflow runs on), not a tag.
   - Location: `.github/workflows/maestro-rollout.yml:60-66`
   - What's wrong: `workflow_dispatch` sets `GITHUB_REF=refs/heads/<branch>`, not `refs/tags/...`. The expression `${GITHUB_REF#refs/tags/}` only strips the `refs/tags/` prefix when present; for a branch ref it leaves the value as `refs/heads/main`. That string is then passed as `--version refs/heads/main` to `install_satellite.py`, becomes the branch name `maestro/bump-refs/heads/main-<ts>` (which contains an embedded `refs/heads/` segment and an extra slash), and is splashed into the PR title as `Bump Maestro to refs/heads/main`.
   - User-observable consequence: The README tells the user "dispatch the rollout manually … use the `ref` input"; if they leave `ref` blank (the default the form offers) the rollout ships shims pinned to `refs/heads/main` and opens a PR titled `Bump Maestro to refs/heads/main`. The branch name with a slashed ref also makes the resulting git ref awkward (creates `maestro/bump-refs/heads/main-<ts>`, which has four path components).
   - Suggested fix: After the strip, also strip `refs/heads/` (and fall back to a clearer error if neither prefix matched on the dispatch path), or require the `ref` input on `workflow_dispatch`.

3. **risk**: The `EOF` heredoc terminator and body indentation are coupled to YAML block-indent stripping; any future edit that re-indents this run block by a different amount silently breaks the heredoc.
   - Location: `.github/workflows/maestro-rollout.yml:184-200`
   - What's wrong: The heredoc uses unquoted `<<EOF` (not `<<-EOF`), so `EOF` must appear at column 0 in the *shell* script. Today that works because the YAML `run: |` block-strips a common 10-space indent and both the `EOF` line and the body lines happen to sit at exactly 10 spaces in the YAML. The `cat > "$BODY_FILE" <<EOF` line is at 12 spaces, so it lives inside the `while` loop at column 2 in shell, while the body and closing `EOF` are flush left. Anyone re-indenting the loop body (e.g. wrapping it in another `if`) without also re-indenting the heredoc body and terminator will produce either a non-terminating heredoc or a body with stray leading spaces (which then breaks the markdown fence and the `$(cat ...)` substitution layout).
   - User-observable consequence: A future cosmetic edit produces a rollout that either hangs waiting for `EOF`, or opens PRs whose bodies have a leading `    ` on every line — rendering the markdown as a code block.
   - Suggested fix: Use `<<-EOF` and indent the body with leading tabs, or move the body template out to a file under `.github/` and read it with `gh pr create --body-file`.

4. **risk**: `git commit` runs with `user.email = 41898282+github-actions[bot]@users.noreply.github.com` but the push is authenticated as the human PAT owner; this contradicts the PR description.
   - Location: `.github/workflows/maestro-rollout.yml:106-107`
   - What's wrong: The invocation context says "Bump PRs appear authored by the PAT owner (typically the human running Maestro)". Setting `user.name`/`user.email` to the `github-actions[bot]` identity makes the *commit author* the bot, while the PAT only determines who *opens the PR*. In the satellite, the PR's commit list shows `github-actions[bot]` as the author and the human as the PR creator. If the satellite has a "require commits authored by repo collaborators" rule (some branch-protection setups do), the bot author may be rejected even though the PAT is valid.
   - User-observable consequence: A subtle attribution mismatch in every bump PR — the PR is "by you" but the commit is "by github-actions[bot]". Satellites configured to require human-authored commits will reject the push for an opaque reason.
   - Suggested fix: Either embrace the bot identity in the docs, or set `user.name`/`user.email` to a value tied to the PAT owner (e.g. read from `gh api user` once at the top of the step).

5. **risk**: `set -u` without `set -e` lets failures inside an iteration silently fall through to subsequent commands.
   - Location: `.github/workflows/maestro-rollout.yml:96` (and the loop body 115-213)
   - What's wrong: Only the script-author-anticipated failure points are wrapped in `if !`. If `git add -A` or `git checkout -b "$BRANCH"` fails (e.g. the branch name collides with an existing ref because two dispatches landed in the same UTC second), the script continues to `git commit` (which will error because the index is empty or HEAD didn't move), and then to `git push -u origin "$BRANCH"`, which pushes whatever ref `BRANCH` happens to resolve to. A `git commit` failure with `set -u` only is not detected — the next `if ! git push` runs anyway and may push an unintended branch (or fail with a confusing error).
   - User-observable consequence: Edge-case failures (branch collision, unexpected `git` error) don't increment `FAIL_COUNT` and may corrupt the rollout summary or open PRs against the wrong branch state.
   - Suggested fix: Add `set -e` at the top and wrap each per-satellite block in a function returning a status, or explicitly check the exit code of every git command.

6. **risk**: The `head:maestro/bump-` PR search relies on the GitHub search index, which lags real-time by minutes; a bump PR opened seconds ago by a previous workflow run won't be found and closed.
   - Location: `.github/workflows/maestro-rollout.yml:161`
   - What's wrong: `gh pr list --search "head:maestro/bump-"` hits the search API, not the list API. GitHub's search index is eventually consistent with a documented lag (typically a few minutes, occasionally longer). If two tag pushes occur in quick succession (rare but possible: tag, immediate hotfix re-tag), the second rollout's superseded-PR search may return empty even though an open `maestro/bump-*` PR exists, leaving two competing bump PRs in the satellite — exactly the situation the docs claim doesn't happen ("you never end up with two competing bump PRs").
   - User-observable consequence: Back-to-back rollouts leave two open bump PRs in each satellite, contradicting the README.
   - Suggested fix: Use `gh pr list -R "$SAT" --state open --json number,headRefName` (list, not search) and filter `headRefName` client-side with `jq 'select(.headRefName | startswith("maestro/bump-"))'`.

7. **smell**: `wc -l` reports 0 lines when the file has content but no trailing newline, masking entries on systems where the registry edit didn't end with `\n`.
   - Location: `.github/workflows/maestro-rollout.yml:80`
   - What's wrong: After the (already-broken) pipeline produces `satellites.list`, `wc -l` counts newlines, not non-empty lines. A registry with one entry but no trailing newline (some editors strip it) produces `count=0` and skips the rollout step. The `grep .` upstream emits its own trailing newline, so today it's accidentally fine for the single-satellite case — but the count semantics are still off.
   - User-observable consequence: Combined with finding 1, the counting is misleading; a user manually inspecting the step output sees `count=1` for two satellites and `count=0` for two satellites with a missing trailing newline.
   - Suggested fix: Count with `grep -c .` or `awk 'END{print NR}'` after normalizing line endings.

8. **smell**: The "structural" tests are pure `grep -q` checks that pass on substrings appearing anywhere in the YAML — including inside comments — so they would not catch the trigger being removed if any comment mentioning `tags:` survived.
   - Location: `tests/test_rollout_workflow.sh:35-65` and `.maestro/evidence/14/verify-pr3.sh:25-34`
   - What's wrong: Every assertion is `grep -q '<substring>' "$WF"`. If a future edit moves the `tags:` trigger into a comment, replaces `'v*'` with `'v[0-9]*'`, or refactors the empty-registry guard to a different expression, the tests still pass on the literal substring left behind elsewhere. The tests also don't parse the YAML, so they wouldn't catch a syntactically broken workflow that GitHub Actions would reject at parse time.
   - User-observable consequence: The test suite is green for any edit that leaves the magic strings around — false confidence. The revert-demo proves the tests detect file deletion, not file corruption.
   - Suggested fix: Parse the YAML with `yq` (or `python -c "import yaml"` already used elsewhere in the repo) and assert against the parsed structure — e.g. `.on.push.tags == ['v*']`.
