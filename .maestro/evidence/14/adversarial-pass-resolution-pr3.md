# Adversarial pass — resolution (PR 3)

Resolutions for each finding in `adversarial-review-pr3.md`. The captured review is preserved verbatim.

## Finding 1 (bug) — `tr -d '[:space:]'` concatenated multi-entry registries onto one line

**Fixed.** Replaced the broken `grep -Ev | tr -d | grep .` pipeline in the registry-read step with a per-line `awk` block that strips surrounding whitespace, skips blank/comment lines, validates the `owner/repo` shape, and prints one valid entry per line. Malformed lines fail the step explicitly with a clear error instead of silently corrupting the rollout. Test section 10 locks the regression (asserts `tr -d '[:space:]'` is gone and `awk` is used).

## Finding 2 (bug) — `workflow_dispatch` with no ref resolved to `refs/heads/main`

**Fixed.** The `ref` input on `workflow_dispatch` is now `required: true` (no default), so the dispatch form forces a value. The resolver step also now explicitly checks: if `INPUT_REF` is empty and the event isn't a tag push, it errors out with a clear message naming the actual `GITHUB_REF` it saw. Test section 11 locks the `required: true` assertion.

## Finding 3 (risk) — Heredoc indentation coupled to YAML block-strip

**Fixed.** The PR-body assembly no longer uses a YAML-embedded heredoc. Each line of the body is now built with a series of `printf` calls inside a `{ ... } > "$BODY_FILE"` group, and `gh pr create --body-file` reads it back. Re-indenting the loop body in the future no longer risks breaking the body template.

## Finding 4 (risk) — Commit author was `github-actions[bot]` while PR author was the PAT owner

**Fixed.** The rollout step now reads the PAT owner's identity from `gh api user` (login + numeric id) at the top of the step and sets `git config --global user.name` / `user.email` to that identity (using the standard `<id>+<login>@users.noreply.github.com` form). The PR creator and the commit author now match, which also satisfies satellites that have "require human-authored commits" branch-protection rules. Test section 13 locks the use of `gh api user`.

## Finding 5 (risk) — `set -u` without `set -e` let unanticipated git failures fall through silently

**Fixed.** Restructured the per-satellite block into an inline subshell that runs under `set -eu -o pipefail`. Any unanticipated failure (git, gh, awk, etc.) inside that subshell aborts the satellite and increments `FAIL_COUNT`. The outer loop runs under `set -u` only, so a single bad satellite doesn't kill the whole rollout. Sentinel exit codes (0 = bumped, 100 = already-at-ref) distinguish the success modes. Test section 14 locks the `set -eu -o pipefail` requirement.

## Finding 6 (risk) — Superseded-PR cleanup used the search API (which lags real-time)

**Fixed.** Switched from `gh pr list --search "head:maestro/bump-"` to `gh pr list --state open --json number,headRefName --jq '.[] | select(.headRefName | startswith("maestro/bump-"))'` — the list API returns real-time state. Back-to-back rollouts now reliably close the previous open bump PR before opening a new one. Test section 12 locks the regression (asserts the search API isn't used and the list+jq pattern is).

## Finding 7 (smell) — `wc -l` counted newlines, not entries

**Fixed.** Replaced `wc -l` with `awk 'END{print NR}'`, which counts records regardless of whether the file ended with a newline. Trailing-newline behavior is now consistent.

## Finding 8 (smell) — Structural tests are pure substring greps

**Deliberately not addressed in this PR — partially mitigated.** The new test sections (10–14) added in response to findings 1–6 use more targeted patterns (asserting specific implementation choices rather than just "the magic string exists somewhere"), which raises the test bar somewhat. Switching the whole structural test to a YAML-parser-based check would buy stronger guarantees but adds a non-stdlib dependency (`yq` or `python yaml`); the project currently has no other YAML-parsing tests. Worth revisiting if the structural test surface grows further.

ChatGPT Codex's review will land on PR 3 separately — the adversarial pass above is the internal Implementer-run review that ships as evidence; Codex's review will appear as PR review comments after the PR opens.
