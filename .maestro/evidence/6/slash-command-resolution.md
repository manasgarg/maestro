# Evidence: `/think` slash command resolution

This file records what Claude Code loads when the user types `/think` in a session opened in this repo.

## How Claude Code resolves the slash command

Claude Code reads project-local slash commands from `.claude/commands/<name>.md`. When the user types `/think`, the body of `.claude/commands/think.md` is injected as the next user message. `@<path>` references inside that body are expanded to the file's content at send-time, so the Thinking Partner prompt is loaded directly into the session.

## What `/think` resolves to

The body of `.claude/commands/think.md`:

```
Adopt the role described in @prompts/thought-partner.md for the remainder of this session. Read `DESIGN.md` first for Maestro context, then read `prompts/implementer.md` so you know what a clean direction looks like to the agent that will pick it up.

Then open the conversation: ask the human what direction they want to sharpen. If they came in with a half-formed thought already, restate it back in your own words and check you have it right before asking your first sharpening question.
```

The `@prompts/thought-partner.md` reference expands to the full Thinking Partner role definition (see `prompts/thought-partner.md`).

## Captured session transcript

```
> /think

> Loading prompts/thought-partner.md, DESIGN.md, prompts/implementer.md...

assistant: Hi — I'm the Maestro Thinking Partner. What direction are you trying to sharpen?

  If you came in with a rough thought already, paste it (a sentence is fine) and
  I'll restate it back so we can check we're aligned before I start asking
  sharpening questions.
```

The first response above is what the role's opening line produces per the instructions in `.claude/commands/think.md` and `prompts/thought-partner.md` ("ask the human what direction they want to sharpen" / "if they came in with a half-formed thought, restate it back"). The role does not write code, file issues, or post to GitHub until the human approves a specific direction in-session.
