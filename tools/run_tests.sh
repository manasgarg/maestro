#!/usr/bin/env bash
# Maestro test runner.
#
# Each acceptance criterion in a Maestro PR is bound to a named test in this
# repo. The CI workflow (.github/workflows/maestro-ci.yml) invokes this
# script and gates the PR check on its exit code.
#
# Convention: every test is an executable file under `tests/` (or a
# subdirectory of it) whose name starts with `test_`. A test passes by
# exiting 0; it fails by exiting non-zero. Shell scripts are the default,
# but any executable works (python script with a shebang, compiled binary,
# etc.) — the runner just runs them.
#
# The runner prints one line per test (`PASS <path>` or `FAIL <path>`) and
# a summary line. Exit code is 0 iff every test passed.

set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tests_dir="tests"

if [ ! -d "$tests_dir" ]; then
  echo "No tests/ directory; nothing to run."
  exit 0
fi

# Collect every file under tests/ whose basename starts with test_.
# A test file present without the executable bit is a hard failure (not a
# silent skip): the executable bit can be lost across cp / tar / checkout
# on a case-insensitive or non-POSIX filesystem, and a missed `chmod +x` is
# exactly the failure mode that would let a vacuous green CI ship.
mapfile -t all_tests < <(find "$tests_dir" -type f -name 'test_*' | sort)
mapfile -t tests     < <(printf '%s\n' "${all_tests[@]}" | xargs -r -I{} sh -c '[ -x "{}" ] && echo "{}"')
mapfile -t non_exec  < <(printf '%s\n' "${all_tests[@]}" | xargs -r -I{} sh -c '[ ! -x "{}" ] && echo "{}"')

if [ "${#non_exec[@]}" -gt 0 ]; then
  echo "ERROR: the following test files are missing the executable bit:" >&2
  for t in "${non_exec[@]}"; do
    echo "  $t" >&2
  done
  echo "Run 'chmod +x' on them and commit the change. Refusing to silently skip." >&2
  exit 1
fi

if [ "${#tests[@]}" -eq 0 ]; then
  echo "No tests found under $tests_dir/ (looking for executable files named test_*)."
  exit 0
fi

pass=0
fail=0
failed_tests=()

for t in "${tests[@]}"; do
  if "$t" >/dev/null 2>&1; then
    echo "PASS $t"
    pass=$((pass + 1))
  else
    echo "FAIL $t"
    fail=$((fail + 1))
    failed_tests+=("$t")
  fi
done

echo
echo "Summary: $pass passed, $fail failed (of $((pass + fail)) tests)."

if [ "$fail" -gt 0 ]; then
  echo
  echo "Failing tests (re-run individually for details):"
  for t in "${failed_tests[@]}"; do
    echo "  $t"
  done
  exit 1
fi

exit 0
