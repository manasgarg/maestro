# Adversarial review of #11 — Demo + Pre-mortem + Tests + Adversarial pass

## Findings

1. **bug**: `tools/run_tests.sh` silently skips tests that lack the user-executable bit.
   - Location: `tools/run_tests.sh:30` (the `find` call)
   - What's wrong: The collector is `find "$tests_dir" -type f -name 'test_*' -perm -u+x | sort`. A test file added to `tests/` without `chmod +x` matches `-name 'test_*'` but fails the `-perm -u+x` filter, so it is silently excluded from the run. There is no warning, no enumeration of "skipped" files, and the summary line cheerfully reports the smaller count as the total. On macOS, on a Windows-checkout, or after `cp`/extracting from a tarball, the executable bit is commonly lost.
   - User-observable consequence: A contributor adds `tests/test_new_criterion.sh` that would catch a regression, forgets `chmod +x`, opens a PR. CI is green. The criterion has *no test* despite the PR claiming it does. This is precisely the vacuous-CI failure mode this PR exists to prevent.
   - Suggested fix: After the `find`, also collect `find "$tests_dir" -type f -name 'test_*' ! -perm -u+x` and either auto-`chmod +x` them, or print `SKIP <path> (not executable)` and exit non-zero. Treat "test file present but not runnable" as a hard failure, not a silent skip.

2. **risk**: `test_test_per_criterion_convention.sh` has greps so loose they pass on text unrelated to the convention being tested.
   - Location: `tests/test_test_per_criterion_convention.sh:21` and `:36` (`grep -q 'test'` against the PR template; `grep -qi 'test'` against the reviewer prompt)
   - What's wrong: The word "test" appears throughout both files in unrelated contexts (e.g. "testing the pull request", "test plan", "you're a reviewer, not a..."). These two assertions would still pass even if every reference to citing an automated test path were stripped from the PR template and reviewer prompt. The test does not anchor on `tools/run_tests.sh` or `tests/` for the template check, nor on the "audits each criterion is bound to a test" phrasing for the reviewer.
   - User-observable consequence: A future edit that removes the "by test name and repo-relative path" instruction from the template, or removes the "Is the criterion bound to a named automated test" line from the reviewer prompt, would not be caught by CI — exactly the regression this test is supposed to detect.
   - Suggested fix: Tighten both greps. For the template, require something like `grep -q 'test name.*path\|by test name' "$tpl"`. For the reviewer, require `grep -q 'named automated test\|cites.*test\|bound to.*test'`.

3. **risk**: `tests/test_ci_gate_workflow.sh`'s "vacuousness check" lacks the positive-control half, so a runner that *always* exits non-zero would pass it.
   - Location: `tests/test_ci_gate_workflow.sh:35-43`
   - What's wrong: The subtest writes one passing and one failing test into a tempdir and asserts the runner exits non-zero. It never runs the runner against only-passing tests and asserts exit 0. A regression that makes `run_tests.sh` unconditionally return 1 (e.g. a stray `exit 1` at the end, an inverted final condition) would pass this test while breaking CI on every PR.
   - User-observable consequence: The test that exists to guarantee the CI gate is meaningful does not actually guarantee both halves of meaningful (red on fail, green on pass). A real bug in the runner could ship with this test green.
   - Suggested fix: Add a second sub-block: write only `test_passing.sh` into a fresh tempdir, run the runner, assert it exits 0. Two assertions, one for each direction.
