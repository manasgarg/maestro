---
source: https://github.com/manasgarg/maestro/pull/4
date: 2026-05-15
tags: [github-actions, github-events]
---

GitHub's `issue_comment` event fires only on `created`, `edited`, and `deleted` — never on reactions. A workflow that asks the user to "react with 👍 to approve" describes a no-op: the reaction lands, but no workflow run is dispatched.

Use actual comment text matching for approval signals (a positive comment by the issue author such as "go", "approved", "lgtm"). If you need a lower-friction signal than a comment, the alternatives are a label change (`issues: labeled` fires reliably) or a manual `workflow_dispatch` trigger — both produce events, reactions do not.

This applies to every `reactions`-shaped UX in GitHub Actions; the platform deliberately does not surface reactions as workflow triggers.
