#!/usr/bin/env bash
# Acceptance criterion 7 (issue #11):
# Before the Implementer opens the PR, a separate adversarial pass runs
# over the diff with the single job of finding bugs; its findings and how
# they were addressed are committed as evidence and summarized in the PR.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$repo_root/prompts/adversarial-reviewer.md" ] \
  || fail "prompts/adversarial-reviewer.md does not exist."

# The adversarial prompt must declare its job (find bugs) and how it
# differs from the Reviewer (no evidence-vs-criteria audit).
grep -qi 'find bugs' "$repo_root/prompts/adversarial-reviewer.md" \
  || fail "Adversarial reviewer prompt does not declare bug-finding as its job."

grep -qi 'evidence.*criteria\|criteria.*evidence' "$repo_root/prompts/adversarial-reviewer.md" \
  || fail "Adversarial reviewer prompt does not distinguish itself from the Reviewer's evidence-vs-criteria audit."

# Implementer prompt must spawn the adversarial pass before opening the PR.
grep -q 'Adversarial pass' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not mention the Adversarial pass."

grep -q 'before opening the PR\|before the PR opens' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require the adversarial pass to run before the PR opens."

grep -q 'adversarial-review\.md' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not specify the adversarial-review.md evidence path."

# PR template has the Adversarial pass section.
grep -q '^## Adversarial pass' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template is missing the '## Adversarial pass' section."

grep -q 'adversarial-review\.md' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template does not point at the adversarial-review.md evidence file."
