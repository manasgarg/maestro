# Evidence: end-to-end demo — Thinking-Partner-filed direction

A throwaway `maestro:direction` issue was filed demonstrating the format a Thinking Partner session produces, then immediately closed (state_reason: `not_planned`) so the Implementer does not act on it.

- **Issue URL:** https://github.com/manasgarg/maestro/issues/8
- **Title:** `[demo / throwaway] Sample Thinking-Partner-filed direction`
- **Labels applied:** `maestro:direction` only (no `maestro:ai-proposed`, per the labeling rule for TP-filed-with-in-session-approval)
- **State:** closed (not_planned), immediately

The body follows the format defined in `prompts/thought-partner.md`:

- `## What I want` — observable description of the desired outcome
- `## Why (optional)` — context for decomposition
- `## Scope` — atomic-piece hint
- `## Acceptance criteria` — observable criteria
- Trailing italic footer attesting in-session approval and the labeling decision

This is the body shape the Implementer's `## Triggering events → A. New direction filed` flow consumes directly: no further translation needed before the Implementer posts its proposal.
