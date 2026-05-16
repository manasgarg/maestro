#!/usr/bin/env bash
# Open a PR in manasgarg/maestro carrying a workflow-level learning
# extracted from a satellite repo.
#
# Usage:
#   tools/upstream_learning.sh <path-to-learning-file>
#
# Authentication: uses whatever credentials gh CLI is configured with.
# In an interactive Claude Code session inside a satellite, that's
# typically your own `gh auth login`. In a scheduled satellite workflow,
# set GH_TOKEN to a PAT named MAESTRO_UPSTREAM_PAT (see README).
#
# Upstream target: hardcoded to manasgarg/maestro. Satellites installed
# from a Maestro fork have no upstream route in v1 — workflow-level
# learnings produced by a fork-based satellite should be PR'd manually,
# or kept local. (A future direction can teach this script to read the
# upstream target from a .maestro/upstream config file.)
#
# This script does NOT delete or modify the local learning file in the
# satellite — that's the satellite synthesizer's call. It only opens the
# upstream PR. If the synthesizer wants to keep the learning local too
# (a learning that's both repo-specific AND worth surfacing), it can.

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $(basename "$0") <path-to-learning-file>" >&2
  exit 2
fi

LEARNING_FILE="$1"
if [ ! -f "$LEARNING_FILE" ]; then
  echo "ERROR: learning file not found: $LEARNING_FILE" >&2
  exit 1
fi

# Validate the file looks like a learning (has frontmatter). Catches
# typos like passing the directory or a stray temp file.
if ! head -1 "$LEARNING_FILE" | grep -q '^---$'; then
  echo "ERROR: $LEARNING_FILE does not start with a YAML frontmatter block (---). Is this a learning file?" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not installed. Install from https://cli.github.com/ to open upstream learning PRs." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI is not authenticated. Run 'gh auth login' (interactive sessions) or set GH_TOKEN / MAESTRO_UPSTREAM_PAT (CI)." >&2
  exit 1
fi

# Discover the source repo BEFORE we cd away. `gh repo view` reads from
# the current working directory's git remotes; failure (e.g., not in a
# git repo) is non-fatal — we just record "unknown source" in the PR.
SOURCE_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown-source")

# Read the gh user identity once (used for both the commit and the PR
# attribution). With a PAT this is the PAT owner; with personal auth
# this is the human running the session.
GH_USER=$(gh api user --jq .login)
GH_USER_ID=$(gh api user --jq .id)

# Resolve the absolute path of the source file before cd-ing.
LEARNING_ABS="$(cd "$(dirname "$LEARNING_FILE")" && pwd)/$(basename "$LEARNING_FILE")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Use a token-embedded clone URL when GH_TOKEN is set, so that the
# subsequent `git push` (which inherits the remote URL set by clone)
# also authenticates without needing a separate credential helper.
# In an interactive session, `gh auth login` already installed the
# credential helper, but in a satellite CI run only GH_TOKEN is
# available — plain `git push` would otherwise prompt for credentials
# and fail. (Same pattern as maestro-rollout.yml in PR 3, but inline.)
if [ -n "${GH_TOKEN:-}" ]; then
  CLONE_URL="https://x-access-token:${GH_TOKEN}@github.com/manasgarg/maestro.git"
else
  CLONE_URL="https://github.com/manasgarg/maestro.git"
fi

echo "Cloning manasgarg/maestro into $TMP ..."
if ! git clone --depth 1 "$CLONE_URL" "$TMP" 2>&1 | sed "s|x-access-token:[^@]*@|x-access-token:***@|g"; then
  echo "ERROR: could not clone manasgarg/maestro. Check your auth and network." >&2
  exit 1
fi

cd "$TMP"

LEARNING_NAME="$(basename "$LEARNING_ABS")"
DEST=".maestro/learnings/$LEARNING_NAME"
SLUG="$(basename "$LEARNING_NAME" .md)"

# Existing-file check: if Maestro already has a learning with this
# filename on main, refuse rather than silently overwriting. The
# human can rename the file and re-run.
if [ -f "$DEST" ]; then
  echo "ERROR: manasgarg/maestro already has a learning at $DEST." >&2
  echo "Either:" >&2
  echo "  - your satellite's candidate duplicates an existing Maestro learning (skip it), or" >&2
  echo "  - your candidate is a refinement (supersede the existing one — see prompts/synthesizer.md), or" >&2
  echo "  - the slug clashes by accident (rename your file and re-run)." >&2
  exit 1
fi

# Also check for an open upstream PR with the same slug. Two satellites
# racing on the same candidate would otherwise both pass the on-main
# check and both open PRs; the second to merge would silently clobber
# the first's INDEX.md and content. The check is best-effort — if it
# fails (gh rate-limit, network blip), we still continue rather than
# block, since the on-main check is the harder guarantee.
EXISTING_PR=$(gh -R manasgarg/maestro pr list --state open --search "Upstream learning: $SLUG in:title" --json number,url -q '.[0].url' 2>/dev/null || true)
if [ -n "$EXISTING_PR" ]; then
  echo "ERROR: another upstream PR is already open for this slug in manasgarg/maestro:" >&2
  echo "  $EXISTING_PR" >&2
  echo "Either rebase onto that one, supersede it (different slug + supersedes: in frontmatter), or wait for it to merge." >&2
  exit 1
fi

cp "$LEARNING_ABS" "$DEST"

echo "Regenerating .maestro/learnings/INDEX.md ..."
python3 tools/build_learnings_index.py

git config user.name  "$GH_USER"
git config user.email "${GH_USER_ID}+${GH_USER}@users.noreply.github.com"

BRANCH="upstream/${SLUG}-$(date -u +%Y%m%d%H%M%S)"
git checkout -b "$BRANCH"
git add "$DEST" ".maestro/learnings/INDEX.md"
git commit -m "upstream: $SLUG (from $SOURCE_REPO)"

if ! git push -u origin "$BRANCH"; then
  echo "ERROR: could not push branch '$BRANCH' to manasgarg/maestro. Check that your auth (gh / MAESTRO_UPSTREAM_PAT) has 'Contents: Read and write' on manasgarg/maestro." >&2
  exit 1
fi

BODY_FILE="$(mktemp)"
{
  printf 'Workflow-level learning extracted from `%s` and routed upstream by `tools/upstream_learning.sh`.\n\n' "$SOURCE_REPO"
  printf '## Why this is upstream and not repo-specific\n\n'
  printf 'The synthesizer (or `/maestro-intake`) running in the source satellite classified this candidate as **workflow-level** — i.e., a durable insight about the Maestro process itself (workflows, prompts, evidence conventions, agent behavior) that a future session in any repo would benefit from, not a fact about the source satellite'"'"'s own domain.\n\n'
  printf 'If after reading you decide this is actually repo-specific to the source satellite: close this PR and the source satellite keeps its local copy (under its own `.maestro/learnings/`).\n\n'
  printf '## The learning\n\n'
  printf '```markdown\n'
  cat "$DEST"
  printf '\n```\n\n'
  printf '## Auto-generated\n\n'
  printf 'Opened by `tools/upstream_learning.sh` from a Claude Code session in `%s`. Merging this PR adds the learning to Maestro'"'"'s shared `.maestro/learnings/` and includes it in the regenerated `INDEX.md` (already done in this branch). Closing it leaves Maestro untouched — the satellite still has the learning locally if its synthesizer kept a copy.\n' "$SOURCE_REPO"
} > "$BODY_FILE"

echo "Opening upstream PR ..."
gh pr create \
  --title "Upstream learning: $SLUG (from $SOURCE_REPO)" \
  --body-file "$BODY_FILE" \
  --head "$BRANCH"

rm -f "$BODY_FILE"
echo "Done."
