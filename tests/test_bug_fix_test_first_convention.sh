#!/usr/bin/env bash
# Acceptance criterion 6 (issue #11):
# For bug-fix PRs specifically, git log shows the failing test in an
# earlier commit than the fix. This test verifies the convention is
# encoded in the Implementer and Reviewer prompts.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'Bug-fix' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt is missing the bug-fix section."

# The two-commit pattern must be explicit (test commit, then fix commit).
grep -q 'separate, earlier commit' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require the failing test in a separate, earlier commit than the fix."

grep -q 'Do not squash' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not forbid squashing the test commit and the fix commit."

grep -qi 'bug.*fix\|bug-fix' "$repo_root/prompts/reviewer.md" \
  || fail "Reviewer prompt does not audit the bug-fix test-first commit pattern."
