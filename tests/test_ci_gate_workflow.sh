#!/usr/bin/env bash
# Acceptance criterion 4 (issue #11):
# A CI workflow runs those tests on every PR push and turns the check red
# on any failure.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

workflow="$repo_root/.github/workflows/maestro-ci.yml"

[ -f "$workflow" ] || fail ".github/workflows/maestro-ci.yml does not exist."

grep -q 'pull_request:' "$workflow" \
  || fail "CI workflow does not trigger on pull_request events."

grep -q 'tools/run_tests.sh' "$workflow" \
  || fail "CI workflow does not invoke tools/run_tests.sh."

# The runner has to be meaningful in BOTH directions: red on any failing
# test, green when all tests pass. A runner that unconditionally returned
# non-zero would pass a one-sided check, so verify both halves.

tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# --- Negative control: one failing test → exit non-zero. ---
neg="$tmproot/neg"
mkdir -p "$neg/tests" "$neg/tools"
cp "$repo_root/tools/run_tests.sh" "$neg/tools/run_tests.sh"
chmod +x "$neg/tools/run_tests.sh"
cat > "$neg/tests/test_passing.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$neg/tests/test_failing.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$neg/tests/test_passing.sh" "$neg/tests/test_failing.sh"

if (cd "$neg" && ./tools/run_tests.sh) >/dev/null 2>&1; then
  fail "Test runner exited 0 when one of the tests was failing."
fi

# --- Positive control: only-passing tests → exit 0. ---
pos="$tmproot/pos"
mkdir -p "$pos/tests" "$pos/tools"
cp "$repo_root/tools/run_tests.sh" "$pos/tools/run_tests.sh"
chmod +x "$pos/tools/run_tests.sh"
cat > "$pos/tests/test_a.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$pos/tests/test_b.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$pos/tests/test_a.sh" "$pos/tests/test_b.sh"

if ! (cd "$pos" && ./tools/run_tests.sh) >/dev/null 2>&1; then
  fail "Test runner exited non-zero when every test was passing."
fi
