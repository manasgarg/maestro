#!/usr/bin/env bash
# Acceptance test for PR 3 / issue #14:
# Maestro keeps a registry of satellites at satellites.txt. The rollout
# workflow reads it; lines that aren't comments or blank must be valid
# `owner/repo` references.

set -eu

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

REGISTRY="$repo_root/satellites.txt"

# --- 1. The registry file exists. Without it, the rollout workflow logs
#       a notice and skips silently — keeping the file present (even if
#       empty) makes the absence of registered satellites a deliberate
#       state rather than an accident. ---
[ -f "$REGISTRY" ] || fail "satellites.txt does not exist; the rollout workflow cannot find the registry."

# --- 2. Every non-comment, non-blank line is a valid owner/repo. The
#       rollout step iterates these lines and clones github.com/<line>.git;
#       a malformed line would make the rollout fail on that satellite. ---
INVALID=$(grep -Ev '^\s*(#|$)' "$REGISTRY" | grep -Ev '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || true)
if [ -n "$INVALID" ]; then
  fail "satellites.txt contains lines that aren't valid owner/repo references:\n$INVALID"
fi
