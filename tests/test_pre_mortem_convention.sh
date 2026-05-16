#!/usr/bin/env bash
# Acceptance criterion 2 (issue #11):
# Every PR's description has a Pre-mortem section listing named risks the
# Implementer considered and what was done about each.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q '^## Pre-mortem' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template is missing a '## Pre-mortem' section."

grep -qi 'mitigation' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template's Pre-mortem section does not pair each risk with a mitigation."

grep -q 'Pre-mortem' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require a Pre-mortem per PR."

grep -q 'Pre-mortem' "$repo_root/prompts/reviewer.md" \
  || fail "Reviewer prompt does not mention auditing the Pre-mortem section."
