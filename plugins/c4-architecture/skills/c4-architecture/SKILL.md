---
name: c4-architecture
description: >
  Triggers when the user asks to model software architecture,
  generate C4 diagrams, create or update a Structurizr DSL workspace,
  or mentions C4, Structurizr, architecture modelling, architecture
  visualisation, system context diagrams, container diagrams, or
  component diagrams.
disable-model-invocation: true
context: fork
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

# C4 Architecture Skill

This skill generates C4 architecture models in Structurizr DSL. The DSL file (`architecture/workspace.dsl`) is the primary output — a source of truth that AI agents can read, maintain, and update as the codebase evolves. Rendering to PNG or SVG images is secondary and optional.

## Design Philosophy

The `workspace.dsl` is designed to be **diffable in pull requests**. When architecture changes alongside code, reviewers see the structural impact in the DSL diff.

Key principles:

- **Model all 3 useful C4 levels** — System Context, Container, and Component. Level 4 (Code) is what the IDE already shows; skip it.
- **Component-level modelling is standard, not optional.** Without it, most code changes won't produce DSL diffs and the model goes stale.
- **Keep the DSL content-focused.** No styles section — C4-PlantUML provides sensible defaults. Every line in the file carries architectural meaning.
- **Components map to real code boundaries** — handlers, services, repositories, middleware, event processors — logical groupings, not individual classes.

## Repository Layout

The DSL is versioned alongside the code it describes:

```
project-root/
├── architecture/
│   ├── workspace.dsl          # Committed — the architecture source of truth
│   └── .diagrams/             # Gitignored — rendered output
```

On first generation, create the `architecture/` directory, write the DSL file, and add `architecture/.diagrams/` to the project's `.gitignore`.

## Monorepos and Multi-System Repositories

For monorepos containing multiple independently deployable systems:

- Model each system as a separate `softwareSystem` within a single workspace.
- Use a `systemLandscape` view to show how the systems relate.
- Each system's containers and components are modelled as usual.
- Consider using `!identifiers hierarchical` to avoid identifier collisions across systems.

The single `architecture/workspace.dsl` file remains the output — one file captures the full picture.

## When To Use

- The user asks to **analyse** or **document** how a codebase is structured
- The user wants a **C4 model** or **C4 diagrams** (system context, container, component)
- The user asks to **create or update** an `architecture/workspace.dsl` file
- The user wants **rendered diagram images** (PNG/SVG) of their architecture
- A code change has structural impact and the **DSL should be updated** to match
- The user mentions **C4**, **Structurizr**, or **architecture visualisation**

## Architecture Analysis Process

### Step 1 — Discover the System

Scan the codebase to build a mental model of the architecture. Read broadly before writing anything.

**Build and config files** — identify the technology stack:
- `package.json`, `tsconfig.json`, `nest-cli.json`
- `pom.xml`, `build.gradle`, `build.gradle.kts`
- `go.mod`, `go.sum`
- `Cargo.toml`
- `requirements.txt`, `pyproject.toml`, `setup.py`
- `docker-compose.yml`, `Dockerfile`
- Kubernetes manifests, Terraform files, Helm charts
- `.env.example`, configuration files

**Identify elements at every C4 level:**

| Level | What to find | Where to look |
|-------|-------------|---------------|
| People | Who interacts with the system? | README, auth config, user role definitions, API docs |
| Software Systems | The primary system plus any third-party dependencies | Environment variables, config files, outbound API client code |
| Containers | Separately deployed units — APIs, frontends, data stores, brokers | docker-compose.yml, Kubernetes manifests, top-level project directories |
| Components | Logical groupings inside each container | Source tree — look for handlers, domain services, data-access modules, third-party clients, middleware, event consumers |

**Trace how the pieces connect:**
- Synchronous calls between services (HTTP, gRPC, GraphQL)
- Data store reads and writes (SQL, document, key-value)
- Asynchronous messaging (publish/subscribe, event streams)
- Outbound calls to third-party APIs
- Endpoints exposed to users or other systems
- Intra-container dependencies between components

### Step 2 — Generate the DSL

Write the workspace to `architecture/workspace.dsl`.

Consult the bundled reference material (in this skill's directory):
- **DSL reference:** `references/structurizr-dsl-reference.md`
- **Example workspace:** `examples/example-workspace.dsl`

**Workspace structure:**

```
workspace "System Name" "One-line description." {
    model {
        // People
        // External Systems
        // Primary Software System with Containers and Components
        // Relationships at all levels
    }
    views {
        // System Context, Container, and Component views
    }
}
```

**Semantic tags** — apply tags that convey architectural meaning:
- `"Database"` on databases (rendered as cylinders by C4-PlantUML)
- `"External"` on external software systems
- `"Queue"` on message queues and event buses

**Identifiers:** Use flat (default) identifiers for single-system workspaces — they're simpler and more readable. Switch to `!identifiers hierarchical` only for multi-system workspaces where name collisions would occur. See the DSL reference for details.

**Naming conventions:**
- Identifiers in `camelCase`: `webApp`, `videoService`, `analyticsDb`
- Human-readable display names: `"Web Application"`, `"Video Service"`
- Specific technology labels: `"React SPA"`, `"Go / Chi"`, `"ClickHouse"`

**Relationships** — define at the lowest relevant level:
- Every relationship needs a **description** of what is communicated: `"Sends viewing events to"`, `"Queries user profiles from"`
- Add a **technology** label where known: `"HTTPS/JSON"`, `"gRPC"`, `"AMQP"`, `"TCP"`
- Arrow direction follows who initiates: `caller -> callee`

**Implied relationships** — Structurizr automatically propagates relationships upward. A component-level relationship implies a container-level one, which in turn implies a system-level one. Follow these rules:

- Define relationships at the **lowest relevant level** (component or container)
- Do **not** redefine relationships at higher levels that are already implied — this causes validation errors (`"A relationship … already exists"`)
- Only define explicit system-level relationships for connections that **cannot** be inferred from lower levels (e.g., person-to-system relationships when no person-to-container relationship exists)
- The implied description inherits from the lowest-level relationship; if different wording is needed at the system context level, use `!impliedRelationships false` and define all levels manually (trade-off: more maintenance)

### Step 3 — Create Views

Generate views for all three core C4 levels:

1. **systemContext** — shows the primary system, its actors, and external system dependencies
   ```
   systemContext <softwareSystem> "SystemContext" {
       include *
       autoLayout
   }
   ```

2. **container** — shows the internal structure of the primary system
   ```
   container <softwareSystem> "Containers" {
       include *
       autoLayout
   }
   ```

3. **component** — one view per container that has components defined
   ```
   component <container> "ComponentsOfContainerName" {
       include *
       autoLayout
   }
   ```

**Optional views** (generate when relevant information is available — see `references/structurizr-dsl-advanced.md` for syntax):

- **deployment** — if infrastructure details are present (Kubernetes, Terraform, docker-compose)
- **dynamic** — for key behavioural flows that clarify runtime interactions

Apply `autoLayout` to every view unless the user specifies a manual layout.

### Step 4 — Validate

If `structurizr-cli` is installed, validate the workspace:

```bash
structurizr-cli validate -workspace architecture/workspace.dsl
```

If validation fails, read the error output, fix the DSL, and retry. Attempt up to 3 fix-and-validate cycles.

If `structurizr-cli` is not installed, skip validation and note that the user can install it for validation:

```bash
brew install structurizr-cli
```

> **Note:** The standalone Structurizr CLI is being consolidated into
> [Structurizr vNext](https://github.com/structurizr/structurizr) (v6.0.0, Apache-2.0 licence).
> The `export` and `validate` commands remain free and open source.

Do not prompt to install tools during generation. Just note availability as optional.

### Step 5 — Update .gitignore

Check the project's `.gitignore`. If `architecture/.diagrams/` is not already listed, add it. The rendered output directory should not be committed.

### Step 6 — Render (optional)

The DSL file is the primary deliverable. Only render images if the user requests them.

Rendering uses a temp directory for intermediate `.puml` files so that `.diagrams/` only contains final SVG images — no `.puml` noise.

```bash
tmpdir=$(mktemp -d)
structurizr-cli export \
  -workspace architecture/workspace.dsl \
  -format plantuml/c4plantuml \
  -output "$tmpdir"
for f in "$tmpdir"/structurizr-*.puml; do mv "$f" "$tmpdir/$(basename "$f" | sed 's/^structurizr-//')"; done
mkdir -p architecture/.diagrams
plantuml -tsvg -o "$(pwd)/architecture/.diagrams" "$tmpdir"/*.puml
rm -rf "$tmpdir"
```

SVG is the sole output format: scalable (no pixelation on dense diagrams), text is searchable and selectable, and renders natively in browsers, GitHub markdown, and VS Code preview.

If the tools are not installed:

```bash
brew install structurizr-cli plantuml
```

Do not block the workflow on rendering. The DSL is always generated regardless of tool availability.

## Keeping the DSL in Sync with Code

When updating a codebase, check whether the changes have architectural impact and update the DSL accordingly:

| Code change | DSL action |
|-------------|------------|
| New service, database, or message queue | Add a container and create a component view for it |
| New handler, service class, or repository | Add a component to the appropriate container |
| New API call or external integration | Add a relationship at the lowest relevant level (implied relationships propagate upward) |
| Removed or renamed element | Update or remove it from the model |
| Bug fix or internal refactor with no structural change | No DSL change needed |

The DSL diff in the pull request shows reviewers the architectural impact of the code change. This is the core value of maintaining the model alongside the code.

## Quality Checklist

Run through this checklist before handing the workspace to the user:

- [ ] Every identified system, container, and component appears in the model
- [ ] Containers with meaningful internal structure have components defined
- [ ] Each container with components has a corresponding component view
- [ ] Elements carry descriptions and technology labels
- [ ] Relationship descriptions say what flows, not just "uses" or "calls"
- [ ] Relationships are defined at the lowest relevant level; no duplicates of implied relationships
- [ ] External systems carry the `"External"` tag
- [ ] Data stores carry the `"Database"` tag
- [ ] Message brokers carry the `"Queue"` tag
- [ ] Every view has `autoLayout`
- [ ] No `styles` block — rendering defaults come from C4-PlantUML
- [ ] Output is written to `architecture/workspace.dsl`
- [ ] `architecture/.diagrams/` is listed in `.gitignore`
