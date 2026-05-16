#!/usr/bin/env bash
# Self-verification for issue #7 (Synthesize learnings from every interaction).
# Drives every acceptance criterion the runner can self-verify and writes a
# captured log + supporting artifacts under .maestro/evidence/7/.
#
# Re-run from repo root: bash .maestro/evidence/7/verify.sh
set -uo pipefail

EVIDENCE_DIR=".maestro/evidence/7"
LOG="$EVIDENCE_DIR/verification.log"
PASS=0
FAIL=0

mkdir -p "$EVIDENCE_DIR"
: > "$LOG"

say() {
  echo "$*" | tee -a "$LOG"
}

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    say "PASS  $label"
    PASS=$((PASS+1))
  else
    say "FAIL  $label"
    FAIL=$((FAIL+1))
  fi
}

section() {
  say ""
  say "=== $1 ==="
}

say "Maestro issue #7 — self-verification"
say "run: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
say "cwd: $(pwd)"

# ---------------------------------------------------------------------------
section "Files present"
# ---------------------------------------------------------------------------
check "prompts/synthesizer.md exists" test -f prompts/synthesizer.md
check ".maestro/learnings/ exists"    test -d .maestro/learnings
check "INDEX.md exists"               test -f .maestro/learnings/INDEX.md
check "README.md exists"              test -f .maestro/learnings/README.md
check ".last-synthesized-at exists"   test -f .maestro/learnings/.last-synthesized-at
check "build_learnings_index.py exists" test -f tools/build_learnings_index.py
check "CLAUDE.md exists"              test -f CLAUDE.md
check "maestro-learn.yml workflow exists" test -f .github/workflows/maestro-learn.yml
check ".claude/commands/learn.md exists"  test -f .claude/commands/learn.md

# ---------------------------------------------------------------------------
section "Synthesizer prompt structure"
# ---------------------------------------------------------------------------
check "has 'What IS a learning' section"  grep -q "## What IS a learning" prompts/synthesizer.md
check "has 'What is NOT a learning' calibration" grep -q "## What is NOT a learning" prompts/synthesizer.md
check "has 'Supersedes mechanics' section" grep -q "## Supersedes mechanics" prompts/synthesizer.md
check "describes scheduled batch mode (A)" grep -q "Mode A: scheduled batch" prompts/synthesizer.md
check "describes on-demand mode (B)"       grep -q "Mode B: on-demand from a session" prompts/synthesizer.md
check "default-to-skip is binding principle" grep -q "default is to skip" prompts/synthesizer.md

# ---------------------------------------------------------------------------
section "Seed learnings: frontmatter valid"
# ---------------------------------------------------------------------------
SEED_FILES=$(find .maestro/learnings -maxdepth 1 -name '*.md' ! -name 'INDEX.md' ! -name 'README.md')
SEED_COUNT=$(echo "$SEED_FILES" | grep -c .)
check "at least 3 seed learnings"  test "$SEED_COUNT" -ge 3

for f in $SEED_FILES; do
  base=$(basename "$f")
  python3 - "$f" <<'PY' >/dev/null 2>&1
import sys, re
text = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
assert m, "no frontmatter"
block = m.group(1)
fm = {}
for line in block.splitlines():
    if not line.strip(): continue
    k, _, v = line.partition(":")
    fm[k.strip()] = v.strip()
assert "source" in fm and fm["source"].startswith(("http://","https://")), "source must be a URL"
assert "date" in fm and re.match(r"^\d{4}-\d{2}-\d{2}$", fm["date"]), "date must be YYYY-MM-DD"
assert "tags" in fm and fm["tags"].startswith("[") and fm["tags"].endswith("]"), "tags must be inline list"
PY
  if [ $? -eq 0 ]; then
    say "PASS  frontmatter valid: $base"
    PASS=$((PASS+1))
  else
    say "FAIL  frontmatter valid: $base"
    FAIL=$((FAIL+1))
  fi
done

# ---------------------------------------------------------------------------
section "Index generator: regenerate + idempotency"
# ---------------------------------------------------------------------------
python3 tools/build_learnings_index.py >/dev/null 2>&1
cp .maestro/learnings/INDEX.md "$EVIDENCE_DIR/index-after-first-build.md"
python3 tools/build_learnings_index.py >/dev/null 2>&1
check "second run produces identical INDEX.md (idempotent)" \
  diff -q "$EVIDENCE_DIR/index-after-first-build.md" .maestro/learnings/INDEX.md

N_LINKS=$(grep -c "\.md\`\](\./" .maestro/learnings/INDEX.md || echo 0)
if [ "$N_LINKS" -ge 3 ]; then
  say "PASS  INDEX.md lists at least 3 seed-learning links"
  PASS=$((PASS+1))
else
  say "FAIL  INDEX.md lists at least 3 seed-learning links (got $N_LINKS)"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
section "Supersedes demo (criterion 2 from proposal)"
# ---------------------------------------------------------------------------
DEMO_TMP=$(mktemp -d)
cp .maestro/learnings/*.md "$DEMO_TMP/" 2>/dev/null
# capture index before any v2 file is added
python3 tools/build_learnings_index.py --dir "$DEMO_TMP" >/dev/null
cp "$DEMO_TMP/INDEX.md" "$EVIDENCE_DIR/supersedes-before.md"

# drop in the v2 file that supersedes the v1
cp "$EVIDENCE_DIR/supersedes-demo/maestro-evidence-as-rerunnable-script-v2.md" "$DEMO_TMP/"
python3 tools/build_learnings_index.py --dir "$DEMO_TMP" >/dev/null
cp "$DEMO_TMP/INDEX.md" "$EVIDENCE_DIR/supersedes-after.md"
rm -rf "$DEMO_TMP"

diff -u "$EVIDENCE_DIR/supersedes-before.md" "$EVIDENCE_DIR/supersedes-after.md" \
  > "$EVIDENCE_DIR/supersedes.diff" || true

AFTER="$EVIDENCE_DIR/supersedes-after.md"
if ! grep -A2 "^### evidence$" "$AFTER" | grep -q 'maestro-evidence-as-rerunnable-script\.md`'; then
  say "PASS  after-supersedes INDEX hides v1 from main groupings"
  PASS=$((PASS+1))
else
  say "FAIL  after-supersedes INDEX hides v1 from main groupings"
  FAIL=$((FAIL+1))
fi
check "after-supersedes INDEX shows v2 as active" \
  grep -q "maestro-evidence-as-rerunnable-script-v2.md" "$AFTER"
check "after-supersedes INDEX has 'Superseded' section" \
  grep -q "^## Superseded$" "$AFTER"
if grep -q "maestro-evidence-as-rerunnable-script.md.*superseded by.*maestro-evidence-as-rerunnable-script-v2.md" "$AFTER"; then
  say "PASS  after-supersedes INDEX links v1 → v2 in Superseded section"
  PASS=$((PASS+1))
else
  say "FAIL  after-supersedes INDEX links v1 → v2 in Superseded section"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
section "CLAUDE.md loadback wiring"
# ---------------------------------------------------------------------------
check "CLAUDE.md instructs sessions to read INDEX.md" \
  grep -q "\.maestro/learnings/INDEX\.md" CLAUDE.md
check "CLAUDE.md references /learn for new findings" \
  grep -q "/learn" CLAUDE.md

# ---------------------------------------------------------------------------
section "Scheduled workflow shape"
# ---------------------------------------------------------------------------
check "workflow uses cron schedule"           grep -q "schedule:" .github/workflows/maestro-learn.yml
check "workflow supports manual dispatch"     grep -q "workflow_dispatch" .github/workflows/maestro-learn.yml
check "workflow uses claude-code-base-action" grep -q "anthropics/claude-code-base-action" .github/workflows/maestro-learn.yml
check "workflow auths via OAuth token (not API key)" \
  bash -c '! grep -q "anthropic_api_key" .github/workflows/maestro-learn.yml && grep -q "CLAUDE_CODE_OAUTH_TOKEN" .github/workflows/maestro-learn.yml'
check "workflow loads synthesizer prompt"     grep -q "prompts/synthesizer.md" .github/workflows/maestro-learn.yml
check "workflow computes window from .last-synthesized-at" \
  grep -q "last-synthesized-at" .github/workflows/maestro-learn.yml
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/maestro-learn.yml'))" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  say "PASS  workflow YAML parses"
  PASS=$((PASS+1))
else
  say "FAIL  workflow YAML parses"
  FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
section "/learn slash command shape"
# ---------------------------------------------------------------------------
check "slash command has frontmatter description" \
  bash -c "head -3 .claude/commands/learn.md | grep -q '^description:'"
check "slash command references synthesizer prompt" \
  grep -q "prompts/synthesizer.md" .claude/commands/learn.md
check "slash command instructs commit directly (no PR)" \
  grep -q "Do not open a PR" .claude/commands/learn.md
check "slash command emphasizes default-to-skip" \
  grep -qi "skip" .claude/commands/learn.md

# ---------------------------------------------------------------------------
section "Loadback (criterion 3): fresh session reads INDEX and cites a learning"
# ---------------------------------------------------------------------------
# Spawned from /tmp with --add-dir to isolate from the parent Claude Code
# session's auto-loaded context. Matches the acceptance criterion's "fresh
# session reads INDEX.md and cites a learning by filename" while being
# reproducible on this runner.
REPO_ROOT="$(pwd)"
LOADBACK_LOG="$EVIDENCE_DIR/loadback-transcript.log"
{
  echo "===== fresh session prompt ====="
  echo "Read $REPO_ROOT/.maestro/learnings/INDEX.md and reply with exactly three .md filenames it links from the .maestro/learnings/ directory. Output filenames only, one per line, no markdown formatting, no other words."
  echo "===== fresh session reply ====="
} > "$LOADBACK_LOG"

if command -v claude >/dev/null 2>&1; then
  (cd /tmp && \
    echo "Read $REPO_ROOT/.maestro/learnings/INDEX.md and reply with exactly three .md filenames it links from the .maestro/learnings/ directory. Output filenames only, one per line, no markdown formatting, no other words." \
    | claude --print --add-dir "$REPO_ROOT") >> "$LOADBACK_LOG" 2>&1
  if grep -q "claude-code-base-action-input-shape.md\|github-reactions-dont-trigger-workflows.md\|maestro-evidence-as-rerunnable-script.md" "$LOADBACK_LOG"; then
    say "PASS  fresh-session loadback cites a real learning filename"
    PASS=$((PASS+1))
  else
    say "FAIL  fresh-session loadback did not cite a real learning filename (see $LOADBACK_LOG)"
    FAIL=$((FAIL+1))
  fi
else
  say "SKIP  fresh-session loadback — \`claude\` CLI not available on this runner"
fi

# ---------------------------------------------------------------------------
section "Skip-path demo (criterion 4): synthesizer correctly produces no learning"
# ---------------------------------------------------------------------------
SKIP_LOG="$EVIDENCE_DIR/skip-demo.log"
{
  echo "===== skip-path scenario ====="
  echo "Input: a one-off typo fix on README.md ('teh' -> 'the'). No conversation, no decisions, no surfacing of any platform behavior."
  echo "Expected: synthesizer outputs SKIP with a reason like 'one-off bug fix, nothing reusable'."
  echo "===== synthesizer reply ====="
} > "$SKIP_LOG"

if command -v claude >/dev/null 2>&1; then
  PROMPT_TMP=$(mktemp)
  {
    cat prompts/synthesizer.md
    echo
    echo "---"
    echo
    echo "## This invocation (Mode C — dry-run / explanation)"
    echo
    echo "Source: a one-off typo fix in README.md, replacing 'teh' with 'the'. No discussion, no design choices, no platform-behavior surfacing."
    echo
    echo "Decide whether anything from this clears the bar for a learning. The default is to skip. Output exactly one line: either 'SKIP: <one-line reason>' or 'WRITE: <one-line slug>'. Nothing else."
  } > "$PROMPT_TMP"
  # Run from /tmp to avoid auto-loading the parent project's CLAUDE.md
  (cd /tmp && claude --print < "$PROMPT_TMP") >> "$SKIP_LOG" 2>&1
  rm -f "$PROMPT_TMP"
  if grep -qi "^SKIP:" "$SKIP_LOG"; then
    say "PASS  synthesizer skipped on non-learning input"
    PASS=$((PASS+1))
  else
    say "FAIL  synthesizer did not skip on non-learning input (see $SKIP_LOG)"
    FAIL=$((FAIL+1))
  fi
else
  say "SKIP  skip-path demo — \`claude\` CLI not available on this runner"
fi

# ---------------------------------------------------------------------------
section "Summary"
# ---------------------------------------------------------------------------
say ""
say "Passed: $PASS"
say "Failed: $FAIL"
say ""
[ "$FAIL" -eq 0 ] && say "ALL GREEN" || say "HAD FAILURES"

exit "$FAIL"
