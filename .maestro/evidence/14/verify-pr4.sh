#!/usr/bin/env bash
# Rerunnable verification for PR 4 / issue #14.
#
# Demonstrates the upstream-learning routing contract:
#   1. The helper script tools/upstream_learning.sh exists, is executable,
#      and validates its inputs.
#   2. The synthesizer prompt has a workflow-vs-repo classification step
#      and routes workflow-level candidates through the helper.
#   3. The intake prompt was updated to use the helper (no longer
#      stages to the obsolete .maestro/upstream-candidates/ directory).
#   4. The reusable maestro-learn workflow accepts the optional
#      MAESTRO_UPSTREAM_PAT secret and forwards it as GH_TOKEN.
#   5. The new structural test passes; the full suite is green.

set -eu
cd "$(git rev-parse --show-toplevel)"

heading() { printf "\n=== %s ===\n" "$1"; }

heading "1. Helper script exists, is executable, validates inputs"
SCRIPT=tools/upstream_learning.sh
[ -f "$SCRIPT" ] && [ -x "$SCRIPT" ] && echo "  OK  $SCRIPT exists and is executable"
"$SCRIPT" 2>&1 | grep -q 'Usage:'   && echo "  OK  prints usage when called with no args"
"$SCRIPT" /nonexistent 2>&1 | grep -q 'file not found'  && echo "  OK  errors on missing file"
TMP=$(mktemp)
echo "not a learning" > "$TMP"
"$SCRIPT" "$TMP" 2>&1 | grep -q 'frontmatter' && echo "  OK  rejects files without YAML frontmatter"
rm -f "$TMP"

heading "2. Synthesizer prompt classifies workflow vs repo and routes via the helper"
grep -q 'workflow-level' prompts/synthesizer.md            && echo "  OK  classification step present"
grep -q 'tools/upstream_learning.sh' prompts/synthesizer.md && echo "  OK  references the helper script"

heading "3. Intake prompt was migrated off the .maestro/upstream-candidates/ staging"
grep -q 'tools/upstream_learning.sh' prompts/intake.md  && echo "  OK  intake references the helper"
if grep -q '\.maestro/upstream-candidates/' prompts/intake.md; then
  echo "  FAIL  intake still references the obsolete staging directory"
  exit 1
else
  echo "  OK  no stale references to .maestro/upstream-candidates/"
fi

heading "4. Reusable maestro-learn workflow forwards MAESTRO_UPSTREAM_PAT to gh"
WF=.github/workflows/maestro-learn.yml
grep -q 'MAESTRO_UPSTREAM_PAT' "$WF"                      && echo "  OK  declared as a workflow_call secret"
awk '/MAESTRO_UPSTREAM_PAT:/,/^[^[:space:]]/' "$WF" | grep -q 'required: false' && echo "  OK  declared optional (Maestro-side runs don't need it)"
grep -q 'GH_TOKEN:.*MAESTRO_UPSTREAM_PAT' "$WF"           && echo "  OK  forwarded to the synthesizer step as GH_TOKEN"

heading "5. Full test suite"
tools/run_tests.sh
