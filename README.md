# Codeliance-Skills

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin marketplace (skills and mods) by [Codeliance](https://codeliance.com).

## Installation

```
/plugin marketplace add CodelianceAI/Codeliance-Skills
```

Then install individual plugins:

```
/plugin install <plugin-name>@codeliance-skills
```

## Available Plugins

### c4-architecture

C4 architecture modelling with Structurizr DSL. Analyses codebases and produces a `workspace.dsl` capturing the system's structure at all 3 useful C4 levels (System Context, Container, Component). The DSL is designed to be diffable in pull requests — when code changes have architectural impact, reviewers see it in the DSL diff.

```
/plugin install c4-architecture@codeliance-skills
```

**Slash command:** `/c4`

See [plugins/c4-architecture/README.md](plugins/c4-architecture/README.md) for full documentation.

### continue-session

A [mod](https://code.claude.com/docs/en/plugins/mods/overview) that gives Claude a `continueInNewSession(prompt)` tool: when the current unit of work is done, the agent hands off to a fresh session, which starts with `/clear` and then that prompt. Useful for working through a queue of plans without one context filling up.

```
/plugin install continue-session@codeliance-skills
```

Requires Claude Code v2.1.287 or later. Mods run inside Claude Code with your permissions and are not sandboxed; this one clears the conversation and submits prompts as you, so read its README before installing.

**Tool:** `mcp__continue-session__continueInNewSession` · **Slash command:** `/continue-resend`

See [plugins/continue-session/README.md](plugins/continue-session/README.md) for full documentation.
