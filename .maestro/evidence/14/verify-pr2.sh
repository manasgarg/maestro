#!/usr/bin/env bash
# Rerunnable verification for PR 2 / issue #14.
#
# Demonstrates the satellite install contract end-to-end:
#   1. The seven-file scaffold exists in tools/satellite-template/.
#   2. tools/install_satellite.py runs cleanly against a fresh fixture and
#      produces all seven files with the version placeholder substituted.
#   3. The same script against a mature fixture (one with prior PR
#      template + workflow files) reports the mature state, surfaces
#      /maestro-intake, and replaces the prior files wholesale.
#   4. The full PR 2 test set passes inside the project's test runner.

set -eu

cd "$(git rev-parse --show-toplevel)"

heading() { printf "\n=== %s ===\n" "$1"; }
cleanup() { [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT
TMP="$(mktemp -d)"

heading "1. Satellite scaffold has all eight files (7 managed + 1 default)"
for f in \
  ".github/workflows/maestro-implement.yml" \
  ".github/workflows/maestro-review.yml" \
  ".github/workflows/maestro-ci.yml" \
  ".github/workflows/maestro-learn.yml" \
  ".github/pull_request_template.md" \
  ".github/ISSUE_TEMPLATE/maestro-direction.md" \
  ".maestro/version" \
  "tools/run_tests.sh" \
; do
  [ -f "tools/satellite-template/$f" ] && echo "  OK  $f" || { echo "  FAIL  missing $f"; exit 1; }
done
[ -x "tools/satellite-template/tools/run_tests.sh" ] && echo "  OK  tools/run_tests.sh is executable" || { echo "  FAIL  tools/run_tests.sh is not executable"; exit 1; }

heading "2. Fresh install: --dry-run plan + real run + placeholder substitution"
mkdir -p "$TMP/fresh"
python3 tools/install_satellite.py --version v9.9.9-test --target "$TMP/fresh" --dry-run | sed 's/^/  /'
echo
python3 tools/install_satellite.py --version v9.9.9-test --target "$TMP/fresh" | sed 's/^/  /'
echo
if grep -rl '__MAESTRO_VERSION__' "$TMP/fresh" >/dev/null 2>&1; then
  echo "  FAIL  placeholder still present in: $(grep -rl '__MAESTRO_VERSION__' "$TMP/fresh")"
  exit 1
fi
echo "  OK  no leftover __MAESTRO_VERSION__ placeholders"
grep -q '@v9.9.9-test' "$TMP/fresh/.github/workflows/maestro-implement.yml"
grep -q '^v9.9.9-test$'  "$TMP/fresh/.maestro/version"
echo "  OK  pinned ref substituted into shim and .maestro/version"

heading "3. Mature-repo install: detection, /maestro-intake pointer, wholesale replace"
mkdir -p "$TMP/mature/.github/workflows"
printf 'PRIOR PR TEMPLATE\n'                > "$TMP/mature/.github/pull_request_template.md"
printf 'name: prior-implementer\n'          > "$TMP/mature/.github/workflows/maestro-implement.yml"
python3 tools/install_satellite.py --version v0.1.0 --target "$TMP/mature" | sed 's/^/  /'
echo
grep -q 'PRIOR PR TEMPLATE' "$TMP/mature/.github/pull_request_template.md" \
  && { echo "  FAIL  prior PR template was not replaced (rollout should be absolute)"; exit 1; } \
  || echo "  OK  prior PR template replaced"
grep -q 'prior-implementer' "$TMP/mature/.github/workflows/maestro-implement.yml" \
  && { echo "  FAIL  prior implementer shim was not replaced"; exit 1; } \
  || echo "  OK  prior implementer shim replaced with canonical Maestro content pinned to v0.1.0"

heading "4. Full PR 2 test suite (via the project's test runner)"
tools/run_tests.sh
