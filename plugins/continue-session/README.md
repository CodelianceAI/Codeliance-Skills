# continue-session

A Claude Code mod that gives the agent a tool:

    mcp__continue-session__continueInNewSession(prompt: string)

When called, the mod waits for the current turn to end, runs `/clear`, and submits `prompt` as the
first user message of the fresh session (as your own words, `asUser`).

Requires Claude Code v2.1.287 or later (`claude --version`).

## Before you install

A mod is code that runs inside Claude Code with your permissions; it is not sandboxed. This one:

- clears your conversation (`/clear`) when the agent calls the tool, and
- submits a prompt the agent wrote as if you had typed it, so the agent can keep working across
  sessions without you. `maxChain` (below) bounds how long that goes on.

It reads and writes only its own plugin store, starts no processes and makes no network requests.
To check that yourself before installing, clone this repository and run:

    claude plugin validate plugins/continue-session

The `hooks:` and `calls:` lines list every event it handles and everything it asks Claude Code to do.

## Install

    /plugin marketplace add CodelianceAI/Codeliance-Skills
    /plugin install continue-session@codeliance-skills

## Kick off a chain

    Take on the plan in openspec/changes/<name>. When it's done, call continueInNewSession with a
    prompt that tells the next session to pick the next best openspec change and do the same,
    including this same instruction. Stop when there is no clear next step.

## Safety rails

- `maxChain` (default 10): handoffs allowed in a row without a message from you. Any prompt you type
  resets it. Set it with `/config` or `pluginConfigs` in settings.
- After the tool is called, other tool calls in that turn are denied (they'd be wiped by `/clear`).
- Subagents can't call it.
- If `/clear` succeeds but the submit doesn't, `/continue-resend` re-sends the saved prompt.

## Dev

Load the working copy instead of the installed one:

    claude --plugin-dir /path/to/continue-session

or permanently, in `~/.claude/settings.json`:

    { "env": { "CLAUDE_CODE_PLUGIN_DIRS": "/path/to/continue-session" } }

Then:

    claude plugin validate .
    claude plugin test .
