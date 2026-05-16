---
source: https://github.com/manasgarg/maestro/pull/4
date: 2026-05-15
tags: [github-actions, claude-code-base-action]
---

`anthropics/claude-code-base-action` only honors its documented inputs (`prompt`, `prompt_file`, `claude_args`, `settings`, `claude_code_oauth_token`, `anthropic_api_key`, plus cloud/cache options). Undocumented inputs like `append_prompt`, `allowed_tools`, or `mcp_config` are silently dropped — the workflow runs green but the agent never receives them.

To pass per-trigger context (the triggering issue number, comment author, PR metadata) to the agent, compose it into the `prompt_file` content itself before invoking the action. To restrict tools, use `--allowed-tools` inside `claude_args`. To configure MCP servers, commit a `.mcp.json` to the repo root.

The lookalike-but-different action `anthropics/claude-code-action` (no `-base-`) does have richer inputs and an internal permission-check layer; it is the right choice when the workflow processes untrusted comment content from contributors. `-base-` is appropriate for owner-only flows where the trust boundary is enforced by `author_association` at the workflow level.
