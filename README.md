# Codeliance-Skills

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill marketplace by [Codeliance](https://codeliance.com).

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
