#!/usr/bin/env bash
# Self-verification for the Maestro v0 bootstrap (PR #2 / closes #1).
# Run by the implementer; output recorded to verification.log next to this script.
# Re-runnable by any reviewer.

set -u
cd "$(git rev-parse --show-toplevel)"

pass=0
fail=0

ok()    { printf "[OK]    %s\n" "$1"; pass=$((pass+1)); }
miss()  { printf "[MISS]  %s\n" "$1"; fail=$((fail+1)); }

printf "=== Bootstrap PR #2 self-verification ===\n"
printf "Run at: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf "Commit: %s\n" "$(git rev-parse HEAD)"
printf "\n"

printf "## File inventory\n"
for f in DESIGN.md README.md prompts/implementer.md prompts/reviewer.md \
         .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml \
         .github/workflows/maestro-bootstrap.yml .github/pull_request_template.md \
         .github/ISSUE_TEMPLATE/maestro-direction.md .maestro/README.md \
         .maestro/tasks.jsonl .maestro/evidence/.gitkeep; do
  if [ -f "$f" ]; then ok "$f ($(wc -c < "$f") bytes)"; else miss "$f"; fi
done
printf "\n"

printf "## Workflow YAML lint (actionlint)\n"
if [ -x /tmp/actionlint ]; then
  if /tmp/actionlint .github/workflows/*.yml; then
    ok "all workflows pass actionlint"
  else
    miss "actionlint reported errors"
  fi
else
  printf "[SKIP]  actionlint not available\n"
fi
printf "\n"

printf "## Workflow YAML parses\n"
for f in .github/workflows/*.yml; do
  if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then ok "$f parses"; else miss "$f"; fi
done
printf "\n"

printf "## DESIGN.md contains all 7 principles\n"
for n in 1 2 3 4 5 6 7; do
  if grep -q "^${n}\. \*\*" DESIGN.md; then ok "principle $n"; else miss "principle $n"; fi
done
printf "\n"

printf "## Implementer prompt: required sections\n"
for s in "Principles (binding" "Triggering events" "Proposal format" "PR format" "Receipt format" "Edge cases"; do
  if grep -q "$s" prompts/implementer.md; then ok "section: $s"; else miss "section: $s"; fi
done
printf "\n"

printf "## Reviewer prompt: required sections\n"
for s in "Audit evidence against acceptance criteria" "blocking" "advisory"; do
  if grep -q "$s" prompts/reviewer.md; then ok "section: $s"; else miss "section: $s"; fi
done
printf "\n"

printf "## Public-repo safety: author_association gate present\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  if grep -q "author_association" "$f"; then ok "$f gated"; else miss "$f gate missing"; fi
done
printf "\n"

printf "## PR template includes Observable change + Evidence sections\n"
for s in "Observable change" "Evidence" "Open AI feedback"; do
  if grep -q "$s" .github/pull_request_template.md; then ok "section: $s"; else miss "section: $s"; fi
done
printf "\n"

printf "## Issue template applies maestro:direction label\n"
if grep -q 'maestro:direction' .github/ISSUE_TEMPLATE/maestro-direction.md; then ok "label set"; else miss "label not set"; fi
printf "\n"

printf "=== SUMMARY ===\n"
printf "Passed: %d\n" "$pass"
printf "Failed: %d\n" "$fail"
[ "$fail" -eq 0 ]
