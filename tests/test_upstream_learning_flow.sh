#!/usr/bin/env bash
# Acceptance test for PR 4 / issue #14:
# When a synthesizer or intake session in a satellite produces a
# workflow-level learning, it routes the learning to manasgarg/maestro
# as a PR (rather than committing it locally in the satellite). The
# helper script tools/upstream_learning.sh does the work; the prompts
# (synthesizer + intake) instruct the agent to call it; the reusable
# maestro-learn workflow accepts an optional MAESTRO_UPSTREAM_PAT
# secret so scheduled satellite runs can use it.
#
# Structural test — the live cross-repo PR creation is exercised when
# the helper script actually runs against a satellite + Maestro pair.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- 1. The helper script exists and is executable. ---
SCRIPT="$repo_root/tools/upstream_learning.sh"
[ -f "$SCRIPT" ] || fail "tools/upstream_learning.sh does not exist; satellites have no way to route workflow-level learnings upstream."
[ -x "$SCRIPT" ] || fail "tools/upstream_learning.sh is not executable; satellite agents would fail to run it."

# --- 2. The script targets manasgarg/maestro (not a fork or a different
#       repo by accident). ---
grep -q 'manasgarg/maestro' "$SCRIPT" \
  || fail "upstream_learning.sh does not target manasgarg/maestro; upstream PRs would go to the wrong repo."

# --- 3. The script validates its input (catches typos and stray temp
#       files before they corrupt anything upstream). ---
grep -q 'YAML frontmatter block' "$SCRIPT" \
  || fail "upstream_learning.sh does not validate that the input file has a learning's frontmatter; a typo could ship garbage upstream."

# --- 4. The script refuses to overwrite an existing learning in Maestro
#       (prevents silent collisions between satellites that independently
#       produce a file with the same slug). ---
grep -q 'already has a learning at' "$SCRIPT" \
  || fail "upstream_learning.sh does not refuse to overwrite an existing learning; collisions would silently replace Maestro's version."

# --- 5. The script uses the gh user's identity for the commit so the PR
#       author and commit author match (same pattern as PR 3's rollout
#       fix). Locks both halves of the contract: reading the gh user
#       (login + id), and actually piping that into git config. A
#       previous draft of this test only checked the read half, which
#       would have let a refactor that dropped 'git config user.email'
#       silently regress (flagged by adversarial pass on PR 4). ---
grep -q 'gh api user --jq .login' "$SCRIPT" \
  || fail "upstream_learning.sh does not read the gh user login; commit author would not match PR author."
grep -q 'gh api user --jq .id' "$SCRIPT" \
  || fail "upstream_learning.sh does not read the gh user id; commit email would not be the canonical noreply form."
grep -q 'git config user.email "\${GH_USER_ID}+\${GH_USER}@users.noreply.github.com"' "$SCRIPT" \
  || fail "upstream_learning.sh does not set git config user.email to the gh user's noreply address; commit identity would not match PR author."

# --- 5b. The script uses a token-embedded clone URL when GH_TOKEN is
#         set, so that the subsequent 'git push' authenticates in CI
#         (where only GH_TOKEN is available, not gh's git credential
#         helper). Locks the adversarial-pass finding on PR 4. ---
grep -q 'x-access-token:\${GH_TOKEN}' "$SCRIPT" \
  || fail "upstream_learning.sh does not embed GH_TOKEN in the clone URL; the scheduled-satellite path's 'git push' would fail with 'could not read Username'."

# --- 5c. The script also refuses to open a duplicate PR when another
#         upstream PR with the same slug is already open in Maestro
#         (closes the race between concurrent satellites flagged by
#         the adversarial pass on PR 4). ---
grep -q 'another upstream PR is already open' "$SCRIPT" \
  || fail "upstream_learning.sh does not check for an existing open upstream PR with the same slug; two satellites racing on the same candidate would both PR."

# --- 6. The synthesizer prompt has a satellite-mode classification step
#       so the agent knows when to route upstream vs commit locally. ---
SYN="$repo_root/prompts/synthesizer.md"
grep -q 'workflow-level' "$SYN" \
  || fail "prompts/synthesizer.md has no workflow-level classification; satellite synthesizers wouldn't know what to route upstream."
grep -q 'tools/upstream_learning.sh' "$SYN" \
  || fail "prompts/synthesizer.md does not reference tools/upstream_learning.sh; satellite synthesizers don't know how to route upstream."

# --- 7. The intake prompt was updated to route workflow-level candidates
#       through the script instead of staging them in the obsolete
#       .maestro/upstream-candidates/ directory (which PR 2 introduced
#       as a temporary measure and this PR replaces). ---
INTAKE="$repo_root/prompts/intake.md"
grep -q 'tools/upstream_learning.sh' "$INTAKE" \
  || fail "prompts/intake.md does not reference tools/upstream_learning.sh; intake's workflow-level candidates wouldn't be PR'd to Maestro."
if grep -q '\.maestro/upstream-candidates/' "$INTAKE"; then
  fail "prompts/intake.md still references .maestro/upstream-candidates/ — the staging directory was PR 2's temporary measure and is now replaced by tools/upstream_learning.sh. Delete the stale reference."
fi

# --- 8. The reusable maestro-learn workflow accepts the optional
#       MAESTRO_UPSTREAM_PAT secret so scheduled satellite runs can use
#       it. The reusable workflow must declare every secret it expects;
#       'secrets: inherit' on the caller is not enough on its own. ---
WF="$repo_root/.github/workflows/maestro-learn.yml"
grep -q 'MAESTRO_UPSTREAM_PAT' "$WF" \
  || fail "maestro-learn.yml does not declare the MAESTRO_UPSTREAM_PAT secret; satellites can't forward their upstream PAT to the synthesizer."
# It should be optional (required: false) so Maestro's own scheduled
# runs (which don't need to route anything upstream) don't break.
# Use a 2-line window after the secret declaration rather than an awk
# range — the range pattern is fragile and would match a `required: false`
# anywhere later in the file (adversarial-pass finding on PR 4).
grep -A2 '^      MAESTRO_UPSTREAM_PAT:' "$WF" | grep -q 'required: false' \
  || fail "maestro-learn.yml's MAESTRO_UPSTREAM_PAT secret is not marked 'required: false' in its own 2-line declaration window; Maestro-side scheduled runs would fail validation."

# --- 9. The synthesizer step forwards the PAT to gh by setting GH_TOKEN.
#       Otherwise the script's gh-auth-status check fails even when the
#       satellite has the PAT secret configured. ---
grep -q 'GH_TOKEN:.*MAESTRO_UPSTREAM_PAT' "$WF" \
  || fail "maestro-learn.yml does not set GH_TOKEN to MAESTRO_UPSTREAM_PAT for the synthesizer step; the upstream script would have no gh auth in a scheduled run."
