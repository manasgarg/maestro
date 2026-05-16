#!/usr/bin/env bash
# Acceptance criterion 1 (issue #11):
# Every PR's description has a numbered Demo section; each step points at a
# captured artifact under .maestro/evidence/<issue-number>/.
#
# This test checks the convention is wired into the PR template, the
# Implementer's instructions, and the Reviewer's audit list.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q '^## Demo' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template is missing a '## Demo' section."

grep -q '\.maestro/evidence/<issue' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template's Demo section does not anchor steps to .maestro/evidence/<issue-number>/."

grep -q 'narrated Demo' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require a narrated Demo per PR."

grep -q 'Demo' "$repo_root/prompts/reviewer.md" \
  || fail "Reviewer prompt does not mention auditing the Demo section."
