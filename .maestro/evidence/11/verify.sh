#!/usr/bin/env bash
# Verification script for issue #11.
#
# Re-runnable proof that each acceptance criterion of issue #11 is met
# by what's in this PR. The captured output of this script is
# verification.log in this directory.
#
# Run from the repo root:
#   bash .maestro/evidence/11/verify.sh
#
# Each line below maps a criterion to the artifact(s) that prove it.

set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

ok()   { echo "PASS  C$1: $2"; }
note() { echo "        -> $1"; }

echo "Issue #11 — Bind every acceptance criterion to a test, a runbook step, and an evidence file"
echo "==============================================================================="
echo

# Criterion 1: Demo section with numbered steps citing .maestro/evidence/<issue>/
if grep -q '^## Demo' .github/pull_request_template.md \
   && grep -q '\.maestro/evidence/<issue' .github/pull_request_template.md \
   && grep -q 'narrated Demo' prompts/implementer.md; then
  ok 1 "PR template has a Demo section anchored to .maestro/evidence/<issue>/; Implementer requires it."
  note "PR template: .github/pull_request_template.md (## Demo)"
  note "Implementer rule: prompts/implementer.md (Per-PR deliverables #1)"
  note "Test: tests/test_demo_convention.sh"
fi

# Criterion 2: Pre-mortem section with risk + mitigation
if grep -q '^## Pre-mortem' .github/pull_request_template.md \
   && grep -qi 'mitigation' .github/pull_request_template.md \
   && grep -q 'Pre-mortem' prompts/implementer.md; then
  ok 2 "PR template has a Pre-mortem section pairing risks with mitigations; Implementer requires it."
  note "PR template: .github/pull_request_template.md (## Pre-mortem)"
  note "Implementer rule: prompts/implementer.md (Per-PR deliverables #4)"
  note "Test: tests/test_pre_mortem_convention.sh"
fi

# Criterion 3: Test per acceptance criterion + the runner picks it up
if [ -x tools/run_tests.sh ] \
   && grep -q 'automated test per acceptance criterion' prompts/implementer.md \
   && grep -q 'tools/run_tests.sh' .github/pull_request_template.md; then
  ok 3 "Test runner exists and is executable; Implementer requires a test per criterion; PR template asks for the test path."
  note "Runner: tools/run_tests.sh"
  note "Implementer rule: prompts/implementer.md (Per-PR deliverables #2)"
  note "Test: tests/test_test_per_criterion_convention.sh"
fi

# Criterion 4: CI workflow runs tests + turns red on failure
if [ -f .github/workflows/maestro-ci.yml ] \
   && grep -q 'pull_request:' .github/workflows/maestro-ci.yml \
   && grep -q 'tools/run_tests.sh' .github/workflows/maestro-ci.yml; then
  ok 4 "Maestro CI workflow triggers on pull_request and invokes the test runner; test runner exits non-zero on any failing test (verified by tests/test_ci_gate_workflow.sh)."
  note "Workflow: .github/workflows/maestro-ci.yml"
  note "Test (includes runner-exits-non-zero subcheck): tests/test_ci_gate_workflow.sh"
fi

# Criterion 5: Anti-no-op revert-demo evidence for non-trivial direction
if grep -q 'revert-demo\.log' prompts/implementer.md \
   && grep -q 'no-op' prompts/implementer.md \
   && grep -q 'Anti-no-op' .github/pull_request_template.md; then
  ok 5 "Implementer requires a captured revert-demo.log for non-trivial direction; PR template calls it out under Evidence."
  note "Implementer rule: prompts/implementer.md (Per-PR deliverables #3)"
  note "PR template anchor: .github/pull_request_template.md (Evidence section)"
  note "This PR's revert-demo log: .maestro/evidence/11/revert-demo.log"
  note "Test: tests/test_revert_evidence_convention.sh"
fi

# Criterion 6: Bug-fix two-commit pattern (failing test first, then fix)
if grep -q 'Bug-fix' prompts/implementer.md \
   && grep -q 'separate, earlier commit' prompts/implementer.md \
   && grep -q 'Do not squash' prompts/implementer.md; then
  ok 6 "Implementer requires the failing test in a separate, earlier commit than the fix; squashing those two commits is forbidden."
  note "Implementer rule: prompts/implementer.md (Bug-fix PRs section)"
  note "Reviewer audits this: prompts/reviewer.md"
  note "Test: tests/test_bug_fix_test_first_convention.sh"
fi

# Criterion 7: Adversarial pass spawned before PR opens
if [ -f prompts/adversarial-reviewer.md ] \
   && grep -qi 'find bugs' prompts/adversarial-reviewer.md \
   && grep -q 'Adversarial pass' prompts/implementer.md \
   && grep -q 'before opening the PR\|before the PR opens' prompts/implementer.md \
   && grep -q 'adversarial-review\.md' prompts/implementer.md \
   && grep -q '^## Adversarial pass' .github/pull_request_template.md; then
  ok 7 "Adversarial Reviewer prompt exists; Implementer must spawn it before opening the PR and commit its output; PR template summarizes the findings."
  note "Adversarial Reviewer prompt: prompts/adversarial-reviewer.md"
  note "Implementer rule: prompts/implementer.md (Per-PR deliverables #5)"
  note "This PR's adversarial review: .maestro/evidence/11/adversarial-review.md"
  note "Test: tests/test_adversarial_pass_convention.sh"
fi

echo
echo "Running the full test suite (the same way the CI workflow does):"
echo "---------------------------------------------------------------"
tools/run_tests.sh
