#!/usr/bin/env bash
# Rerunnable verification for PR 1 / issue #14.
#
# Demonstrates the contract that satellite shims depend on:
#   1. The four Maestro workflows expose a `workflow_call` trigger.
#   2. The agent-running workflows declare `maestro_ref` + the OAuth
#      secret and resolve their prompt source from `.maestro-src/` when
#      called from a satellite (and from the working tree otherwise).
#   3. The structural test that locks this contract in passes.
#   4. The full test suite passes.

set -eu

cd "$(git rev-parse --show-toplevel)"

WFDIR=".github/workflows"

heading() { printf "\n=== %s ===\n" "$1"; }

heading "1. workflow_call triggers (all four)"
for wf in maestro-implement.yml maestro-review.yml maestro-ci.yml maestro-learn.yml; do
  if grep -Eq '^  workflow_call:' "$WFDIR/$wf"; then
    echo "  OK  $wf declares workflow_call"
  else
    echo "  FAIL  $wf is missing workflow_call"
    exit 1
  fi
done

heading "2. agent-running workflows: maestro_ref input + OAuth secret"
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -Eq '^      maestro_ref:' "$WFDIR/$wf"
  grep -Eq '^      CLAUDE_CODE_OAUTH_TOKEN:' "$WFDIR/$wf"
  echo "  OK  $wf"
done

heading "3. satellite-mode prompt sourcing (conditional checkout)"
for wf in maestro-implement.yml maestro-review.yml maestro-learn.yml; do
  grep -q "if: \${{ inputs.maestro_ref != '' }}" "$WFDIR/$wf"
  grep -q "repository: manasgarg/maestro" "$WFDIR/$wf"
  grep -q "path: .maestro-src" "$WFDIR/$wf"
  echo "  OK  $wf checks out Maestro at inputs.maestro_ref into .maestro-src/"
done

heading "4. structural test passes"
tests/test_reusable_workflows.sh
echo "  OK  tests/test_reusable_workflows.sh"

heading "5. full test suite"
tools/run_tests.sh
