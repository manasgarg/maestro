#!/usr/bin/env bash
# Acceptance criterion 5 (issue #11):
# For non-trivial direction, the PR's evidence includes a captured log of
# the demo failing when the change is reverted — proves the change isn't a
# no-op.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'Anti-no-op' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template's Evidence section does not call out anti-no-op revert evidence."

grep -q 'revert-demo' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template does not point at the conventional revert-demo log path."

grep -q 'revert-demo\.log' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require the revert-demo log for non-trivial direction."

grep -q 'no-op' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not frame the revert evidence as anti-no-op."

grep -q 'revert' "$repo_root/prompts/reviewer.md" \
  || fail "Reviewer prompt does not audit the revert evidence for non-trivial direction."
