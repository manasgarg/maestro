#!/usr/bin/env bash
# Acceptance test for PR 2 / issue #14:
# Running tools/install_satellite.py against a fresh empty repo produces
# the satellite scaffold with the __MAESTRO_VERSION__ placeholder
# substituted by the pinned version everywhere it appears.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

target="$(mktemp -d)"
trap 'rm -rf "$target"' EXIT

# --- 1. Install against an empty target. ---
python3 "$repo_root/tools/install_satellite.py" \
  --version v9.9.9-test \
  --target "$target" \
  --source "$repo_root/tools/satellite-template" \
  > "$target/install.log" 2>&1 \
  || fail "install_satellite.py exited non-zero on a fresh target:\n$(cat "$target/install.log")"

# --- 2. All eight expected files exist in the target after install
#       (seven Maestro-managed plus tools/run_tests.sh — the latter is
#       a "default" file scaffolded only when missing; on a fresh repo
#       it's missing, so install writes it). ---
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
  [ -f "$target/$f" ] || fail "install did not produce $f in the target."
done

# tools/run_tests.sh must be executable (the maestro-ci workflow calls
# it directly; without the executable bit, every Maestro CI check is
# red).
[ -x "$target/tools/run_tests.sh" ] \
  || fail "post-install tools/run_tests.sh is not executable; maestro-ci would fail."

# --- 3. The placeholder is fully substituted with the requested version
#       in every file that contained it. A leftover __MAESTRO_VERSION__
#       would mean the satellite calls a non-existent ref and every
#       workflow fails at validation. ---
if grep -rl '__MAESTRO_VERSION__' "$target" >/dev/null 2>&1; then
  fail "install left __MAESTRO_VERSION__ unsubstituted in: $(grep -rl '__MAESTRO_VERSION__' "$target" | sed "s|$target/||" | tr '\n' ' ')"
fi

# --- 4. The pinned version actually appears where we expect it. ---
grep -q '^v9.9.9-test$' "$target/.maestro/version" \
  || fail ".maestro/version does not contain the pinned ref."
grep -q '@v9.9.9-test' "$target/.github/workflows/maestro-implement.yml" \
  || fail "implementer shim's uses: line is not pinned to v9.9.9-test."
grep -q 'maestro_ref: v9.9.9-test' "$target/.github/workflows/maestro-implement.yml" \
  || fail "implementer shim does not pass maestro_ref: v9.9.9-test to the reusable workflow."

# --- 5. The install log identifies this as a fresh repo (no REPLACE
#       actions, only WRITE actions). ---
if grep -q 'Mature repo detected' "$target/install.log"; then
  fail "install on a fresh target wrongly reported the target as mature: $(cat "$target/install.log")"
fi
grep -q '^  WRITE' "$target/install.log" \
  || fail "install log does not show WRITE actions on a fresh target."
if grep -q '^  REPLACE' "$target/install.log"; then
  fail "install on a fresh target wrongly reported REPLACE actions."
fi
