#!/usr/bin/env bash
# Acceptance test for PR 2 / issue #14 (AC 6 — rollout is absolute):
# Running tools/install_satellite.py against a mature repo (one with
# Maestro-managed files already present) detects the mature state,
# REPLACES the conflicting files wholesale, and tells the human about
# /maestro-intake so they can extract any salvageable knowledge first.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

target="$(mktemp -d)"
trap 'rm -rf "$target"' EXIT

# --- 1. Seed a "mature" target with PRIOR content at two
#       Maestro-managed paths. ---
mkdir -p "$target/.github/workflows" "$target/.github/ISSUE_TEMPLATE"
printf 'PRIOR PR TEMPLATE\n' > "$target/.github/pull_request_template.md"
printf 'name: prior-implementer\n' > "$target/.github/workflows/maestro-implement.yml"

# --- 2. Dry-run first: should report mature + show would-replace actions
#       for the two seeded files and would-write for the rest. ---
python3 "$repo_root/tools/install_satellite.py" \
  --version v0.1.0 \
  --target "$target" \
  --source "$repo_root/tools/satellite-template" \
  --dry-run \
  > "$target/dryrun.log" 2>&1 \
  || fail "install --dry-run exited non-zero on a mature target:\n$(cat "$target/dryrun.log")"

grep -q 'Mature repo detected' "$target/dryrun.log" \
  || fail "dry-run did not detect the mature target."
grep -q 'EXISTING.*\.github/workflows/maestro-implement\.yml' "$target/dryrun.log" \
  || fail "dry-run did not flag the existing implementer shim as a conflict."
grep -q 'EXISTING.*\.github/pull_request_template\.md' "$target/dryrun.log" \
  || fail "dry-run did not flag the existing PR template as a conflict."
grep -q '/maestro-intake' "$target/dryrun.log" \
  || fail "dry-run did not point the human at /maestro-intake to salvage prior process knowledge."
grep -q '^  WOULD-REPLACE' "$target/dryrun.log" \
  || fail "dry-run did not show WOULD-REPLACE actions on a mature target."

# Confirm dry-run truly did not write anything.
grep -q 'PRIOR PR TEMPLATE' "$target/.github/pull_request_template.md" \
  || fail "dry-run modified the PR template; it should be untouched."

# --- 3. Real run: replaces the two conflicting files; writes the rest. ---
python3 "$repo_root/tools/install_satellite.py" \
  --version v0.1.0 \
  --target "$target" \
  --source "$repo_root/tools/satellite-template" \
  > "$target/install.log" 2>&1 \
  || fail "install exited non-zero on a mature target:\n$(cat "$target/install.log")"

grep -q '^  REPLACE.*\.github/workflows/maestro-implement\.yml' "$target/install.log" \
  || fail "install did not report REPLACE for the prior implementer shim."
grep -q '^  REPLACE.*\.github/pull_request_template\.md' "$target/install.log" \
  || fail "install did not report REPLACE for the prior PR template."

# --- 4. The PRIOR content is gone — replaced with the canonical
#       pinned-Maestro version. Absolute rollout (AC 6). ---
if grep -q 'PRIOR PR TEMPLATE' "$target/.github/pull_request_template.md"; then
  fail "install did not replace the prior PR template's content; rollout is supposed to be absolute."
fi
if grep -q 'prior-implementer' "$target/.github/workflows/maestro-implement.yml"; then
  fail "install did not replace the prior implementer shim's content; rollout is supposed to be absolute."
fi

# --- 5. The replacement files now contain the canonical Maestro content
#       with the pinned version substituted. ---
grep -q 'Maestro Implementer' "$target/.github/workflows/maestro-implement.yml" \
  || fail "post-install implementer shim does not contain canonical Maestro content."
grep -q '@v0.1.0' "$target/.github/workflows/maestro-implement.yml" \
  || fail "post-install implementer shim is not pinned to v0.1.0."
grep -q 'Observable change' "$target/.github/pull_request_template.md" \
  || fail "post-install PR template does not contain canonical Maestro content."
