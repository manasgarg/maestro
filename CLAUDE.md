# Maestro project memory

This repository is Maestro — an AI-driven dev workflow orchestrator. Read `DESIGN.md` for principles and lifecycle, and `README.md` for the user-facing flow.

## Load past learnings

Before responding to anything substantive in this repo, read `.maestro/learnings/INDEX.md`. It is the table of contents for project-specific insights extracted from past sessions, issue threads, and PR conversations. For any learning whose tag is relevant to the task at hand, open the file and apply it.

You do not need to recite the learnings back to the user. Apply them silently — they exist to make you faster and more correct, not for the user to verify in every reply. The user can read the index themselves.

## When you discover something new

If during a session you discover a durable, reusable insight that is not already captured in `.maestro/learnings/`, run the `/learn` slash command before the session ends. It invokes the Maestro synthesizer (`prompts/synthesizer.md`), which decides whether the candidate clears the bar for a learning. The default is to skip; most sessions produce nothing.

The scheduled workflow (`.github/workflows/maestro-learn.yml`) handles learnings extracted from closed issues and merged PRs automatically — you do not need to trigger it manually.
