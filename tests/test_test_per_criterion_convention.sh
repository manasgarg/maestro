#!/usr/bin/env bash
# Acceptance criterion 3 (issue #11):
# Every acceptance criterion in the PR's Evidence section cites a named
# automated test that lives in the repo.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Test runner exists and is executable.
[ -x "$repo_root/tools/run_tests.sh" ] \
  || fail "tools/run_tests.sh missing or not executable."

# Tests directory exists.
[ -d "$repo_root/tests" ] \
  || fail "tests/ directory does not exist."

# PR template's Evidence section asks for a test name + repo-relative path.
# Loose 'grep test' would pass on unrelated boilerplate; anchor on the
# specific phrasing that names the convention.
grep -q 'automated test' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template's Evidence section does not require citing an automated test."

grep -q 'path/to/test\|path.*test\|test.*path' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template's Evidence section does not require a test path per criterion."

grep -q 'tools/run_tests.sh' "$repo_root/.github/pull_request_template.md" \
  || fail "PR template does not reference the test runner that the CI workflow invokes."

# Implementer prompt requires a test per acceptance criterion.
grep -q 'automated test per acceptance criterion' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not require an automated test per acceptance criterion."

# Implementer prompt instructs to wire the test into the CI runner.
grep -q 'tools/run_tests.sh' "$repo_root/prompts/implementer.md" \
  || fail "Implementer prompt does not point new tests at the CI runner."

# Reviewer audits that each criterion is bound to a named automated test
# (not merely that the word "test" appears somewhere in the prompt).
grep -q 'named automated test\|criterion.*bound.*test\|bound to a named' "$repo_root/prompts/reviewer.md" \
  || fail "Reviewer prompt does not audit that each criterion is bound to a named automated test."
