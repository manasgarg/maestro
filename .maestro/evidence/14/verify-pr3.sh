#!/usr/bin/env bash
# Rerunnable verification for PR 3 / issue #14.
#
# Demonstrates the rollout contract:
#   1. The satellite registry (satellites.txt) exists and parses cleanly.
#   2. The rollout workflow exposes a tag trigger, workflow_dispatch,
#      registry read, install-script call, and the PAT secret reference.
#   3. The two new structural tests pass; the full suite is green.

set -eu

cd "$(git rev-parse --show-toplevel)"

heading() { printf "\n=== %s ===\n" "$1"; }

heading "1. satellites.txt parses (every non-comment, non-blank line is owner/repo)"
[ -f satellites.txt ] && echo "  OK  satellites.txt exists" || { echo "  FAIL  missing satellites.txt"; exit 1; }
INVALID=$(grep -Ev '^\s*(#|$)' satellites.txt | grep -Ev '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || true)
[ -z "$INVALID" ] && echo "  OK  no malformed lines" || { echo "  FAIL  malformed: $INVALID"; exit 1; }
ACTIVE=$(grep -Ev '^\s*(#|$)' satellites.txt | wc -l | tr -d ' ')
echo "  $ACTIVE satellite(s) currently registered"

heading "2. Rollout workflow contract"
WF=.github/workflows/maestro-rollout.yml
[ -f "$WF" ] && echo "  OK  $WF exists" || { echo "  FAIL  missing $WF"; exit 1; }
grep -q "tags:" "$WF"                          && echo "  OK  fires on tag push"
grep -q "'v\*'" "$WF"                          && echo "  OK  matches v* tag pattern"
grep -q '^  workflow_dispatch:' "$WF"          && echo "  OK  supports manual dispatch"
grep -q 'satellites.txt' "$WF"                 && echo "  OK  reads satellites.txt"
grep -q 'tools/install_satellite.py' "$WF"     && echo "  OK  reuses the install script (no drift)"
grep -q 'MAESTRO_ROLLOUT_PAT' "$WF"            && echo "  OK  references MAESTRO_ROLLOUT_PAT for cross-repo writes"
grep -q "steps.registry.outputs.count != '0'" "$WF" && echo "  OK  skips rollout step when no satellites are registered"
grep -q 'head:maestro/bump-' "$WF"             && echo "  OK  closes superseded bump PRs before opening a new one"
grep -q 'MAESTRO_ROLLOUT_PAT secret is not set' "$WF" && echo "  OK  errors early when PAT is missing"

heading "3. Structural tests pass"
tests/test_satellites_registry.sh && echo "  OK  test_satellites_registry.sh"
tests/test_rollout_workflow.sh    && echo "  OK  test_rollout_workflow.sh"

heading "4. Full test suite"
tools/run_tests.sh
