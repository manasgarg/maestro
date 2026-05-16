#!/usr/bin/env bash
# Acceptance test for PR 1 / issue #14:
# The four Maestro workflows (implement, review, ci, learn) expose a
# `workflow_call` trigger so satellite repos can call them at a pinned
# Maestro ref. The three agent-running workflows additionally declare a
# `maestro_ref` input and a `CLAUDE_CODE_OAUTH_TOKEN` secret, and they
# resolve their prompt source from a `.maestro-src/` checkout when called
# from a satellite (and from the working tree when self-invoked).
#
# This is structural: it greps the workflow files for the contract
# satellites depend on. The runtime behavior (a satellite shim actually
# calling these workflows) is exercised in PR 2's install fixture.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

WFDIR="$repo_root/.github/workflows"

# --- 1. All four workflows declare workflow_call. ---
for wf in maestro-implement.yml maestro-review.yml maestro-ci.yml maestro-learn.yml; do
  grep -Eq '^  workflow_call:' "$WFDIR/$wf" \
    || fail "$wf does not declare a workflow_call trigger; satellite shims cannot call it."
done

# --- 2. The agent-running workflows declare maestro_ref + the OAuth secret. ---
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -Eq '^      maestro_ref:' "$WFDIR/$wf" \
    || fail "$wf does not declare the 'maestro_ref' workflow_call input."
  grep -Eq '^      CLAUDE_CODE_OAUTH_TOKEN:' "$WFDIR/$wf" \
    || fail "$wf does not declare the 'CLAUDE_CODE_OAUTH_TOKEN' workflow_call secret."
done

# --- 3. Satellite-mode prompt sourcing: conditional checkout of Maestro
#       at the pinned ref, gated on inputs.maestro_ref being non-empty.
#       This is the contract that lets a satellite at v0.1.0 keep running
#       the v0.1.0 prompts even after Maestro itself moves on. ---
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -q "if: \${{ inputs.maestro_ref != '' }}" "$WFDIR/$wf" \
    || fail "$wf does not gate the satellite-mode Maestro checkout on inputs.maestro_ref."
  grep -q "repository: manasgarg/maestro" "$WFDIR/$wf" \
    || fail "$wf does not check out the Maestro repo to load prompts from."
  grep -q "path: .maestro-src" "$WFDIR/$wf" \
    || fail "$wf does not check out Maestro into the .maestro-src/ sidecar."
  grep -q 'PROMPTS_DIR' "$WFDIR/$wf" \
    || fail "$wf does not parameterize its prompt path on PROMPTS_DIR."
done

# --- 4. The agent-running workflows use the resolved PROMPTS_DIR to read
#       their prompt file (not the hardcoded 'prompts/...' path that would
#       only resolve in self-invocation). ---
grep -q 'cat "\$PROMPTS_DIR/prompts/implementer.md"' "$WFDIR/maestro-implement.yml" \
  || fail "maestro-implement.yml reads prompts/implementer.md from a hardcoded path; satellite mode would fail."
grep -q 'cat "\$PROMPTS_DIR/prompts/reviewer.md"' "$WFDIR/maestro-review.yml" \
  || fail "maestro-review.yml reads prompts/reviewer.md from a hardcoded path; satellite mode would fail."
grep -q 'cat "\$PROMPTS_DIR/prompts/synthesizer.md"' "$WFDIR/maestro-learn.yml" \
  || fail "maestro-learn.yml reads prompts/synthesizer.md from a hardcoded path; satellite mode would fail."

# --- 5. Self-invocation triggers are preserved (no regression on Maestro
#       dogfooding its own workflows). ---
grep -Eq '^  issues:' "$WFDIR/maestro-implement.yml" \
  || fail "maestro-implement.yml lost its 'issues' trigger; Maestro itself stops responding to labels."
grep -Eq '^  issue_comment:' "$WFDIR/maestro-implement.yml" \
  || fail "maestro-implement.yml lost its 'issue_comment' trigger."
grep -Eq '^  pull_request:' "$WFDIR/maestro-implement.yml" \
  || fail "maestro-implement.yml lost its 'pull_request' trigger."
grep -Eq '^  pull_request:' "$WFDIR/maestro-review.yml" \
  || fail "maestro-review.yml lost its 'pull_request' trigger."
grep -Eq '^  schedule:' "$WFDIR/maestro-learn.yml" \
  || fail "maestro-learn.yml lost its 'schedule' trigger."
grep -Eq '^  pull_request:' "$WFDIR/maestro-ci.yml" \
  || fail "maestro-ci.yml lost its 'pull_request' trigger."

# --- 6. Satellite callers are admitted by the job-level `if:`. Without
#       this OR-branch, the github.event_name checks below it silently skip
#       every satellite caller event that isn't issues/issue_comment/
#       pull_request — turning the whole reusable surface into a no-op for
#       any satellite that wires its shim to workflow_dispatch (the
#       obvious "Run Maestro now" button) or any other event. Locks the
#       fix for adversarial finding #1 + #2. ---
for wf in maestro-implement.yml maestro-review.yml; do
  grep -q "inputs.maestro_ref != '' ||" "$WFDIR/$wf" \
    || fail "$wf job-gate doesn't OR on inputs.maestro_ref; satellite callers from any non-issue/PR event silently no-op."
done

# --- 7. Satellite mode injects an explicit path-redirection block into
#       the prompt so the agent doesn't try to read DESIGN.md / prompts/
#       / tools/ from the satellite's working tree. Locks the fix for
#       adversarial finding #3. ---
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -q "Path redirection (satellite mode — binding)" "$WFDIR/$wf" \
    || fail "$wf does not emit the satellite-mode path-redirection block; agent will try to read DESIGN.md / prompts/ / tools/ from the satellite tree where they don't exist."
done
