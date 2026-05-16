#!/usr/bin/env bash
# Acceptance test for PR 2 / issue #14:
# The satellite scaffold template under tools/satellite-template/ contains
# every file a satellite needs and every Maestro-managed file uses the
# __MAESTRO_VERSION__ placeholder where the install script will substitute
# the pinned version.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

TPLDIR="$repo_root/tools/satellite-template"

# --- 1. All seven scaffold files are present. ---
for f in \
  ".github/workflows/maestro-implement.yml" \
  ".github/workflows/maestro-review.yml" \
  ".github/workflows/maestro-ci.yml" \
  ".github/workflows/maestro-learn.yml" \
  ".github/pull_request_template.md" \
  ".github/ISSUE_TEMPLATE/maestro-direction.md" \
  ".maestro/version" \
; do
  [ -f "$TPLDIR/$f" ] || fail "satellite template is missing $f"
done

# --- 2. The four workflow shims plus .maestro/version use the
#       __MAESTRO_VERSION__ placeholder. The install script substitutes
#       it for the pinned ref. ---
for f in \
  ".github/workflows/maestro-implement.yml" \
  ".github/workflows/maestro-review.yml" \
  ".github/workflows/maestro-ci.yml" \
  ".github/workflows/maestro-learn.yml" \
  ".maestro/version" \
; do
  grep -q '__MAESTRO_VERSION__' "$TPLDIR/$f" \
    || fail "$f does not contain the __MAESTRO_VERSION__ placeholder; the install script can't pin it."
done

# --- 3. The shims use Maestro's reusable workflows from manasgarg/maestro
#       (the contract PR 1 established). ---
for wf in maestro-implement.yml maestro-review.yml maestro-ci.yml maestro-learn.yml; do
  grep -q "uses: manasgarg/maestro/.github/workflows/$wf@__MAESTRO_VERSION__" "$TPLDIR/.github/workflows/$wf" \
    || fail "$wf shim does not call manasgarg/maestro's reusable workflow at __MAESTRO_VERSION__."
done

# --- 4. Shims that pass through to agent-running workflows inherit the
#       calling repo's secrets (so CLAUDE_CODE_OAUTH_TOKEN gets forwarded). ---
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -q 'secrets: inherit' "$TPLDIR/.github/workflows/$wf" \
    || fail "$wf shim does not declare 'secrets: inherit'; the OAuth token won't reach the reusable workflow."
done

# --- 5. The shims that need it pass maestro_ref as a with: input. ---
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -q 'maestro_ref: __MAESTRO_VERSION__' "$TPLDIR/.github/workflows/$wf" \
    || fail "$wf shim does not pass maestro_ref to the reusable workflow."
done

# --- 6a. The install workflow (the file the human copies into their
#         satellite as .github/workflows/maestro-install.yml) creates the
#         four Maestro labels itself, so the user doesn't have to run a
#         separate "Maestro Bootstrap" workflow after install. Locks the
#         fix for the adversarial-pass finding that the install was dead
#         on arrival without the labels. ---
INSTALL_WF="$repo_root/tools/maestro-install-workflow.yml"
[ -f "$INSTALL_WF" ] || fail "tools/maestro-install-workflow.yml is missing."
grep -q 'maestro:direction' "$INSTALL_WF" \
  || fail "install workflow does not create the maestro:direction label; satellite loop is dead on arrival without it."
grep -q 'maestro:awaiting-human' "$INSTALL_WF" \
  || fail "install workflow does not create the maestro:awaiting-human label."
grep -q 'maestro:ai-proposed' "$INSTALL_WF" \
  || fail "install workflow does not create the maestro:ai-proposed label."
grep -q 'maestro:done' "$INSTALL_WF" \
  || fail "install workflow does not create the maestro:done label."

# --- 6b. The install workflow handles re-dispatch against an
#         already-installed satellite (no-op) without failing the run.
#         Locks the fix for the adversarial-pass finding that 'git commit'
#         under 'set -eu' would abort on an empty diff. ---
grep -q 'git diff --cached --quiet' "$INSTALL_WF" \
  || fail "install workflow does not detect the no-op case (already pinned to this ref); re-dispatching would fail on 'git commit nothing to commit'."

# --- 6c. The install workflow's PR-creation step does not pass --base
#         (gh defaults to the repo's default branch; the previous draft
#         tried to resolve it via 'git symbolic-ref refs/remotes/origin/HEAD'
#         which actions/checkout@v4 does not configure, so the call died
#         under set -eu and no PR was opened on a fresh satellite). ---
if grep -q 'symbolic-ref refs/remotes/origin/HEAD' "$INSTALL_WF"; then
  fail "install workflow uses 'git symbolic-ref refs/remotes/origin/HEAD' to resolve --base; actions/checkout@v4 doesn't configure that symbolic-ref and the call fails. Drop --base (gh defaults to the repo's default branch) or use 'gh repo view --json defaultBranchRef'."
fi

# --- 7. The intake prompt has a branch guard so /maestro-intake never
#        commits learnings directly to the satellite's default branch
#        (bypassing whatever review process the satellite enforces).
#        Locks the fix for the adversarial-pass finding on prompts/intake.md. ---
INTAKE="$repo_root/prompts/intake.md"
[ -f "$INTAKE" ] || fail "prompts/intake.md is missing."
grep -qi 'branch guard\|default branch' "$INTAKE" \
  || fail "intake prompt has no branch-guard instruction; running /maestro-intake from a default-branch checkout would commit learnings straight to main."

# --- 8. The triggers on each shim mirror Maestro's own triggers — this
#       is the satellite contract established in PR 1 (the reusable surface
#       silently no-ops for non-matching caller events by design). ---
grep -Eq '^  issues:' "$TPLDIR/.github/workflows/maestro-implement.yml" \
  || fail "implementer shim is missing the 'issues' trigger; the satellite won't receive direction labels."
grep -Eq '^  issue_comment:' "$TPLDIR/.github/workflows/maestro-implement.yml" \
  || fail "implementer shim is missing the 'issue_comment' trigger."
grep -Eq '^  pull_request:' "$TPLDIR/.github/workflows/maestro-implement.yml" \
  || fail "implementer shim is missing the 'pull_request' trigger."
grep -Eq '^  pull_request:' "$TPLDIR/.github/workflows/maestro-review.yml" \
  || fail "reviewer shim is missing the 'pull_request' trigger."
grep -Eq '^  schedule:' "$TPLDIR/.github/workflows/maestro-learn.yml" \
  || fail "learn shim is missing the 'schedule' trigger."
grep -Eq '^  pull_request:' "$TPLDIR/.github/workflows/maestro-ci.yml" \
  || fail "CI shim is missing the 'pull_request' trigger."
