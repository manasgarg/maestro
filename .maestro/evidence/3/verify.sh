#!/usr/bin/env bash
# Self-verification for issue #3 — addressing PR #2 reviewer findings.
# Run by the implementer; output recorded to verification.log next to this script.

set -u
cd "$(git rev-parse --show-toplevel)"

pass=0
fail=0

ok()    { printf "[OK]    %s\n" "$1"; pass=$((pass+1)); }
miss()  { printf "[MISS]  %s\n" "$1"; fail=$((fail+1)); }

printf "=== Issue #3 self-verification ===\n"
printf "Run at: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf "Commit: %s\n" "$(git rev-parse HEAD)"
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

printf "## Bogus action inputs removed (finding #1 fix)\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  for bad in append_prompt allowed_tools mcp_config; do
    if grep -q "${bad}:" "$f"; then miss "$f still uses '${bad}'"; else ok "$f: '${bad}' removed"; fi
  done
done
printf "\n"

printf "## Documented action inputs used (finding #1 fix)\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  if grep -q "prompt_file:" "$f"; then ok "$f uses prompt_file"; else miss "$f missing prompt_file"; fi
  if grep -q "claude_args:" "$f"; then ok "$f uses claude_args"; else miss "$f missing claude_args"; fi
done
printf "\n"

printf "## Prompt is composed from role file + dynamic context (finding #1 fix)\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  if grep -q "cat prompts/" "$f" && grep -q "Triggering event\|PR to review" "$f"; then
    ok "$f assembles full prompt"
  else
    miss "$f does not assemble full prompt"
  fi
done
printf "\n"

printf "## .mcp.json configures GitHub MCP server (per action trust-model guidance)\n"
if [ -f .mcp.json ] && python3 -c "import json; d=json.load(open('.mcp.json')); assert 'github' in d.get('mcpServers',{})" 2>/dev/null; then
  ok ".mcp.json present and includes 'github' server"
else
  miss ".mcp.json missing or malformed"
fi
printf "\n"

printf "## Reaction-based approval removed (finding #3 fix)\n"
# README and DESIGN must not say 'React with' or 'reaction' as the approval mechanism.
for f in README.md DESIGN.md; do
  if grep -q "^React with 👍" "$f" || grep -q "approved (a 👍 reaction" "$f"; then
    miss "$f still describes reaction-based approval"
  else
    ok "$f does not claim reactions approve"
  fi
done
# implementer.md must specify comment-based approval.
if grep -q '"go", "approved", "lgtm"' prompts/implementer.md || grep -q '"go" (or "approved"' prompts/implementer.md; then
  ok "implementer.md specifies positive-comment approval"
else
  miss "implementer.md missing comment-based approval text"
fi
printf "\n"

printf "## Setup instructions corrected (your setup-token failure)\n"
for f in README.md DESIGN.md; do
  if grep -q "setup-token" "$f"; then miss "$f still mentions 'setup-token'"; else ok "$f: 'setup-token' removed"; fi
  if grep -q "/install-github-app" "$f"; then ok "$f references /install-github-app"; else miss "$f missing /install-github-app"; fi
done
printf "\n"

printf "## Trust model section present in DESIGN (finding #2 documented override)\n"
if grep -q "^## Trust model" DESIGN.md; then ok "DESIGN.md has Trust model section"; else miss "DESIGN.md missing Trust model section"; fi
printf "\n"

printf "## Public-repo safety gate still present (no regression)\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  if grep -q "author_association" "$f"; then ok "$f gated"; else miss "$f gate missing"; fi
done
printf "\n"

printf "## Auth still uses subscription OAuth token, not API key (no regression)\n"
for f in .github/workflows/maestro-implement.yml .github/workflows/maestro-review.yml; do
  if grep -q "claude_code_oauth_token" "$f" && ! grep -q "ANTHROPIC_API_KEY" "$f"; then
    ok "$f uses CLAUDE_CODE_OAUTH_TOKEN"
  else
    miss "$f auth misconfigured"
  fi
done
printf "\n"

printf "=== SUMMARY ===\n"
printf "Passed: %d\n" "$pass"
printf "Failed: %d\n" "$fail"
[ "$fail" -eq 0 ]
