#!/usr/bin/env bash
# Self-verification for the "add testing & validation" change.
# Each ok/miss assertion's label echoes an acceptance criterion. CI runs this.
# Re-runnable by any reviewer: `bash .maestro/evidence/testing-validation/verify.sh`.

set -u
cd "$(git rev-parse --show-toplevel)"

pass=0
fail=0
ok()   { printf "[OK]   %s\n" "$1"; pass=$((pass+1)); }
miss() { printf "[MISS] %s\n" "$1"; fail=$((fail+1)); }

printf "=== testing-validation self-verification ===\n"
printf "Run at: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf "Commit: %s\n" "$(git rev-parse HEAD)"
printf "\n"

# --- Criterion 1: DESIGN.md introduces principle 8 (criterion-↔-test-↔-evidence binding).
printf "## Criterion 1: DESIGN.md principle 8\n"
if grep -q "^8\. \*\*Each acceptance criterion binds three artifacts" DESIGN.md; then
  ok "Criterion 1: DESIGN.md declares principle 8 (three-artifact binding)"
else
  miss "Criterion 1: DESIGN.md is missing principle 8"
fi
if grep -q "Bug Hunter" DESIGN.md; then
  ok "Criterion 1: DESIGN.md names the Bug Hunter sub-role"
else
  miss "Criterion 1: DESIGN.md does not mention Bug Hunter"
fi
if grep -q "CI gate" DESIGN.md; then
  ok "Criterion 1: DESIGN.md describes the CI gate"
else
  miss "Criterion 1: DESIGN.md does not describe the CI gate"
fi
printf "\n"

# --- Criterion 2: Implementer prompt instructs the new operational steps.
printf "## Criterion 2: implementer.md operational steps\n"
if grep -q "verify.sh" prompts/implementer.md \
   && grep -q "runbook.md" prompts/implementer.md \
   && grep -q "test-catches-it.log" prompts/implementer.md; then
  ok "Criterion 2: implementer.md names the three required artifacts"
else
  miss "Criterion 2: implementer.md missing one of verify.sh/runbook.md/test-catches-it.log"
fi
if grep -q "Adversarial pass" prompts/implementer.md \
   && grep -q "bug-hunter" prompts/implementer.md; then
  ok "Criterion 2: implementer.md describes the adversarial Bug Hunter pass"
else
  miss "Criterion 2: implementer.md missing adversarial-pass instructions"
fi
if grep -q "separate commit before the fix" prompts/implementer.md; then
  ok "Criterion 2: implementer.md requires failing-test-first for bug fixes"
else
  miss "Criterion 2: implementer.md missing failing-test-first rule"
fi
printf "\n"

# --- Criterion 3: Reviewer prompt audits the binding and non-atomic artifacts.
printf "## Criterion 3: reviewer.md audits the binding\n"
if grep -q "criterion-↔-test-↔-evidence binding" prompts/reviewer.md \
   || grep -q "Audit the criterion" prompts/reviewer.md; then
  ok "Criterion 3: reviewer.md audits the criterion-↔-test-↔-evidence binding"
else
  miss "Criterion 3: reviewer.md missing binding audit"
fi
if grep -q "pre-mortem.md" prompts/reviewer.md \
   && grep -q "counterfactual.md" prompts/reviewer.md \
   && grep -q "bug-hunter.log" prompts/reviewer.md; then
  ok "Criterion 3: reviewer.md audits the non-atomic-only artifacts"
else
  miss "Criterion 3: reviewer.md missing non-atomic artifact audit"
fi
printf "\n"

# --- Criterion 4: Bug Hunter prompt exists and is internally consistent.
printf "## Criterion 4: prompts/bug-hunter.md exists\n"
if [ -f prompts/bug-hunter.md ]; then
  ok "Criterion 4: prompts/bug-hunter.md exists"
else
  miss "Criterion 4: prompts/bug-hunter.md missing"
fi
if grep -q "bug-hunter.log" prompts/bug-hunter.md 2>/dev/null \
   && grep -qi "adversarial" prompts/bug-hunter.md 2>/dev/null; then
  ok "Criterion 4: bug-hunter.md writes to bug-hunter.log and is adversarial"
else
  miss "Criterion 4: bug-hunter.md is inconsistent with the role"
fi
printf "\n"

# --- Criterion 5: CI gate workflow exists, runs verify.sh scripts, validates schema.
printf "## Criterion 5: CI gate workflow\n"
if [ -f .github/workflows/maestro-ci.yml ]; then
  ok "Criterion 5: .github/workflows/maestro-ci.yml exists"
else
  miss "Criterion 5: maestro-ci.yml missing"
fi
if grep -q "pull_request" .github/workflows/maestro-ci.yml 2>/dev/null; then
  ok "Criterion 5: CI runs on pull_request"
else
  miss "Criterion 5: CI does not run on pull_request"
fi
if grep -q "actionlint" .github/workflows/maestro-ci.yml 2>/dev/null; then
  ok "Criterion 5: CI runs actionlint"
else
  miss "Criterion 5: CI does not run actionlint"
fi
if grep -q "validate_tasks_jsonl.py" .github/workflows/maestro-ci.yml 2>/dev/null; then
  ok "Criterion 5: CI validates tasks.jsonl schema"
else
  miss "Criterion 5: CI does not validate tasks.jsonl"
fi
if grep -q "validate_evidence.py" .github/workflows/maestro-ci.yml 2>/dev/null; then
  ok "Criterion 5: CI validates evidence-directory structure"
else
  miss "Criterion 5: CI does not validate evidence structure"
fi
if grep -q ".maestro/evidence/\*/verify.sh" .github/workflows/maestro-ci.yml 2>/dev/null; then
  ok "Criterion 5: CI runs every verify.sh under .maestro/evidence/"
else
  miss "Criterion 5: CI does not iterate verify.sh scripts"
fi
printf "\n"

# --- Criterion 6: JSON schema for tasks.jsonl and validation script.
printf "## Criterion 6: tasks.jsonl JSON schema + validator\n"
if [ -f .maestro/schemas/tasks.schema.json ]; then
  ok "Criterion 6: .maestro/schemas/tasks.schema.json exists"
else
  miss "Criterion 6: tasks.schema.json missing"
fi
if python3 -c "import json; json.load(open('.maestro/schemas/tasks.schema.json'))" 2>/dev/null; then
  ok "Criterion 6: tasks.schema.json is valid JSON"
else
  miss "Criterion 6: tasks.schema.json is not valid JSON"
fi
if [ -f .maestro/scripts/validate_tasks_jsonl.py ] && python3 -c "import ast; ast.parse(open('.maestro/scripts/validate_tasks_jsonl.py').read())" 2>/dev/null; then
  ok "Criterion 6: validate_tasks_jsonl.py exists and parses"
else
  miss "Criterion 6: validate_tasks_jsonl.py missing or invalid"
fi
if [ -f .maestro/scripts/validate_evidence.py ] && python3 -c "import ast; ast.parse(open('.maestro/scripts/validate_evidence.py').read())" 2>/dev/null; then
  ok "Criterion 6: validate_evidence.py exists and parses"
else
  miss "Criterion 6: validate_evidence.py missing or invalid"
fi
printf "\n"

# --- Criterion 7: PR template prompts for the new sections.
printf "## Criterion 7: PR template prompts for new sections\n"
for s in "Runbook" "Test mapping" "Test-catches-it" "Pre-mortem" "Counterfactual" "Bug Hunter findings"; do
  if grep -q "$s" .github/pull_request_template.md; then ok "Criterion 7: PR template has \"$s\" section"; else miss "Criterion 7: PR template missing \"$s\""; fi
done
printf "\n"

# --- Criterion 8: legacy evidence dirs are marked and won't fail CI.
printf "## Criterion 8: legacy evidence dirs marked\n"
for d in 2 3 6; do
  if [ -f ".maestro/evidence/$d/LEGACY" ]; then
    ok "Criterion 8: .maestro/evidence/$d/LEGACY present"
  else
    miss "Criterion 8: .maestro/evidence/$d/LEGACY missing"
  fi
done
printf "\n"

# --- Criterion 9: this directory itself satisfies principle 8 (non-atomic).
printf "## Criterion 9: this evidence directory complies with principle 8\n"
SELF=.maestro/evidence/testing-validation
for f in verify.sh runbook.md test-catches-it.log pre-mortem.md counterfactual.md bug-hunter.log NON_ATOMIC; do
  if [ -f "$SELF/$f" ]; then ok "Criterion 9: $SELF/$f exists"; else miss "Criterion 9: $SELF/$f missing"; fi
done
printf "\n"

printf "=== SUMMARY ===\n"
printf "Passed: %d\n" "$pass"
printf "Failed: %d\n" "$fail"
[ "$fail" -eq 0 ]
