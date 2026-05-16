# Adversarial pass — resolution (PR 4)

Resolutions for each finding in `adversarial-review-pr4.md`. The captured review is preserved verbatim.

## Finding 1 (bug) — `git push` had no credential helper, breaking the scheduled-satellite path

**Fixed.** When `GH_TOKEN` is set, the clone URL now embeds the token (`https://x-access-token:${GH_TOKEN}@github.com/manasgarg/maestro.git`). `git push` inherits the remote URL from the clone, so authentication works without a separate credential helper. The clone command's output is piped through `sed` to redact the token if it ever appears in logs. In interactive sessions where `GH_TOKEN` is unset, the plain URL is used and `gh auth login`'s credential helper handles auth as before. Test section 5b locks the regression.

## Finding 2 (bug) — Test 8's `awk` range scanned past the secret declaration

**Fixed.** Replaced the awk-range pattern with `grep -A2 '^      MAESTRO_UPSTREAM_PAT:' | grep -q 'required: false'`. The `-A2` window is bounded to the two lines following the secret declaration, so a stray `required: false` later in the file can't satisfy it.

## Finding 3 (risk) — Hardcoded `manasgarg/maestro` doesn't work for satellites installed from a fork

**Deliberately not addressed in v1; documented.** Added a header comment to `tools/upstream_learning.sh` calling out the limitation explicitly: satellites installed from a Maestro fork have no automated upstream route. Workflow-level learnings from a fork-based satellite are either PR'd manually or kept local. Implementing a config-driven `MAESTRO_UPSTREAM_REPO` override would require teaching the prompts to read it, teaching the install script to seed it, and updating the documentation across both — out of proportion to the edge case (the proposal explicitly names `manasgarg/maestro` throughout). A future direction can lift the constraint.

## Finding 4 (risk) — Two satellites racing on the same slug both pass the on-main check and both PR

**Fixed.** Added a second check after the on-main one: `gh -R manasgarg/maestro pr list --state open --search "Upstream learning: $SLUG in:title" --json number,url`. If any open PR has the same slug in its title, the script refuses with a clear pointer to the existing PR and instructions (rebase, supersede, or wait). The check is best-effort — if the gh call fails (rate-limit, network), we still continue rather than block, since the on-main check is the harder guarantee. Test section 5c locks the regression.

## Finding 5 (smell) — Test 5's `grep -q 'gh api user'` didn't catch the relevant regression

**Fixed.** Replaced the single substring check with three more targeted ones: (a) `gh api user --jq .login` read, (b) `gh api user --jq .id` read, (c) the `git config user.email` line with the canonical `${GH_USER_ID}+${GH_USER}@users.noreply.github.com` form. All three must be present; dropping any one would now fail the test.
