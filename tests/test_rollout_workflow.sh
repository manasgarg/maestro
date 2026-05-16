#!/usr/bin/env bash
# Acceptance test for PR 3 / issue #14:
# The rollout workflow at .github/workflows/maestro-rollout.yml fires on
# tag push, reads satellites.txt, and (in the live run) invokes
# tools/install_satellite.py against each registered satellite using a
# PAT to open a bump PR. This is a structural check — the live cross-repo
# behavior is exercised by tagging the Maestro repo.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

WF="$repo_root/.github/workflows/maestro-rollout.yml"

# --- 1. The rollout workflow exists. ---
[ -f "$WF" ] || fail ".github/workflows/maestro-rollout.yml does not exist."

# --- 2. It fires on tag push (any `v*` tag — semver releases). Without
#       this trigger, releasing a new Maestro version produces no satellite
#       bump PRs and the loop's downstream half is dead. ---
grep -q "tags:" "$WF" || fail "rollout workflow does not declare a tag trigger."
grep -q "'v\*'" "$WF" || fail "rollout workflow does not match the 'v*' tag pattern."

# --- 3. It also supports manual dispatch so the human can re-roll out
#       any ref without having to re-tag. ---
grep -q '^  workflow_dispatch:' "$WF" \
  || fail "rollout workflow does not support workflow_dispatch; the human can't re-roll without re-tagging."

# --- 4. It reads the registry. ---
grep -q 'satellites.txt' "$WF" \
  || fail "rollout workflow does not read satellites.txt."

# --- 5. It invokes the same install script the install workflow uses,
#       so the bump diff is exactly what a fresh install would produce
#       at the new ref. No code duplication; no drift between install
#       and bump behavior. ---
grep -q 'tools/install_satellite.py' "$WF" \
  || fail "rollout workflow does not invoke tools/install_satellite.py; the bump diff would be hand-rolled and would drift from the install."

# --- 6. It requires a PAT (the workflow's built-in GITHUB_TOKEN can't
#       write to a different repo). Without this, every push to a
#       satellite fails with permission denied. ---
grep -q 'MAESTRO_ROLLOUT_PAT' "$WF" \
  || fail "rollout workflow does not reference the MAESTRO_ROLLOUT_PAT secret; cross-repo writes would all fail."

# --- 7. It skips the rollout step (rather than failing the whole job)
#       when no satellites are registered. Without this guard the workflow
#       would error on the first tag push if the registry is empty. ---
grep -q "steps.registry.outputs.count != '0'" "$WF" \
  || fail "rollout workflow does not gate the rollout step on a non-zero registry count; an empty registry would error out."

# --- 8. It closes superseded bump PRs before opening a new one, so each
#       satellite only ever has at most one open "Bump Maestro" PR at
#       any time (same approach as the install workflow's auto-close,
#       per Codex feedback on PR 2). The actual implementation pattern
#       is locked in by section 12 below (list API + jq filter on
#       'maestro/bump-' headRefName prefix). ---
grep -q 'gh -R "\$SAT" pr close' "$WF" \
  || fail "rollout workflow does not close superseded 'maestro/bump-*' PRs in the satellite; satellites would accumulate stale bump PRs."

# --- 9. The PAT-empty case fails fast with a clear message rather than
#       silently continuing and producing a confusing git auth error. ---
grep -q 'MAESTRO_ROLLOUT_PAT secret is not set' "$WF" \
  || fail "rollout workflow does not error early when MAESTRO_ROLLOUT_PAT is missing; a clear error message is required."

# --- 10. Registry parser doesn't 'tr -d [:space:]' the whole file (which
#         would concatenate every entry onto one line and silently break
#         multi-satellite rollouts — the entire point of the registry).
#         Locks the adversarial-pass finding from PR 3 review. ---
if grep -q "tr -d '\[:space:\]'" "$WF"; then
  fail "rollout workflow parses satellites.txt with 'tr -d [:space:]' which concatenates all entries onto one line. Use per-line awk/grep instead."
fi
grep -q "awk '" "$WF" \
  || fail "rollout workflow does not use awk to parse the registry per-line; multi-satellite registries would not iterate correctly."

# --- 11. workflow_dispatch requires the 'ref' input (no default), so a
#         dispatch with the form left blank can't accidentally roll out
#         'refs/heads/main' (GITHUB_REF's value for workflow_dispatch).
#         Locks the adversarial-pass finding from PR 3 review. ---
grep -A2 '^      ref:' "$WF" | grep -q 'required: true' \
  || fail "rollout workflow's 'ref' input is not required; on workflow_dispatch with no ref, the resolver would fall through to GITHUB_REF which is 'refs/heads/<branch>', not a tag."

# --- 12. Superseded-PR cleanup uses the LIST API with --json + jq filter,
#         not the search API. The search index lags real-time by minutes
#         and would miss a bump PR opened seconds ago. Locks the
#         adversarial-pass finding from PR 3 review. ---
if grep -q "pr list --state open --search" "$WF"; then
  fail "rollout workflow uses 'gh pr list --search' to find superseded bump PRs; the search index lags real-time. Switch to '--json + jq select startswith' on the LIST API."
fi
grep -q 'startswith("maestro/bump-")' "$WF" \
  || fail "rollout workflow does not filter open PRs by headRefName startswith 'maestro/bump-' on the list API."

# --- 13. Commit author identity is read from the PAT owner, not hardcoded
#         to github-actions[bot] — so the PR creator and the commit author
#         match. Locks the adversarial-pass finding from PR 3 review. ---
grep -q 'gh api user' "$WF" \
  || fail "rollout workflow does not read the PAT owner's identity from 'gh api user'; commit author would be github-actions[bot] while the PR creator is the human, producing a confusing attribution mismatch."

# --- 14. Per-satellite work runs in a subshell with strict mode so an
#         unanticipated git/gh failure aborts THAT satellite (incrementing
#         FAIL_COUNT) instead of silently falling through. Locks the
#         adversarial-pass finding from PR 3 review. ---
grep -q 'set -eu -o pipefail' "$WF" \
  || fail "rollout workflow does not run the per-satellite block under 'set -eu -o pipefail'; unanticipated failures would fall through silently."
