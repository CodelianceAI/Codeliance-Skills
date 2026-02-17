# Structurizr DSL Quick Reference

Based on the [Structurizr DSL language reference](https://docs.structurizr.com/dsl/language). Structurizr DSL is open source under the Apache-2.0 licence.

For deployment nodes, dynamic views, filtered views, and properties/URLs, see `structurizr-dsl-advanced.md`.

---

## Workspace

```dsl
workspace [name] [description] {
    model { }
    views { }
}
```

- `name` and `description` are optional (quote strings with spaces).

---

## Model Elements

### Person

```dsl
identifier = person "Name" [description] [tags]
```

Default tags: `Element`, `Person`.

### Software System

```dsl
identifier = softwareSystem "Name" [description] [tags] {
    container ... { }
    group "Name" { }
}
```

Default tags: `Element`, `Software System`.

### Container (inside softwareSystem)

```dsl
identifier = container "Name" [description] [technology] [tags] {
    component ... { }
    group "Name" { }
}
```

Default tags: `Element`, `Container`.

### Component (inside container)

```dsl
identifier = component "Name" [description] [technology] [tags]
```

Default tags: `Element`, `Component`.

### Full Nesting Example

```dsl
model {
    user = person "User" "A customer"
    system = softwareSystem "My System" "Does things" {
        webapp = container "Web App" "Serves UI" "React"
        api = container "API" "REST API" "Spring Boot" {
            authCtrl = component "Auth Controller" "Handles auth" "Spring MVC"
            userSvc = component "User Service" "User logic" "Spring Bean"
        }
        db = container "Database" "Stores data" "PostgreSQL" "Database"
    }
    externalSystem = softwareSystem "External System" "Third party" "External"
}
```

### Groups

Groups organize elements visually without affecting model hierarchy.

```dsl
softwareSystem "System" {
    group "Frontend" {
        spa = container "SPA" "" "React"
    }
    group "Backend" {
        api = container "API" "" "Node.js"
    }
}
```

---

## Relationships

```dsl
sourceId -> destId [description] [technology] [tags]
```

**Outside element blocks (explicit):**
```dsl
user -> system "Uses" "HTTPS"
```

**Inside element blocks (implicit source):**
```dsl
api = container "API" {
    -> db "Reads from" "SQL"
}
```

**Implied relationships:** A relationship between lower-level elements (e.g., `user -> api`) automatically implies a relationship between their parents (e.g., `user -> system`). Disable with `!impliedRelationships false`.

**Relationship identifiers:** `rel = user -> system "Uses" "HTTPS"`

---

## Tags

Tags classify elements for filtering. They are additive — they never replace default tags.

**Inline** — the last positional string on an element definition:
```dsl
db = container "Database" "Stores data" "PostgreSQL" "Database"
ext = softwareSystem "External" "Third party" "External"
```

**Via keyword** (inside element block):
```dsl
db = container "Database" {
    tags "Database"
    tags "Storage,Critical"
}
```

Multiple tags: comma-separated `"Tag1,Tag2"` or separate args `"Tag1" "Tag2"`.

**Common semantic tags:** `Database`, `Queue`, `External`, `Mobile`, `Browser`, `Existing`.

**Auto-applied defaults:** `Element` on all elements; type-specific tag (`Person`, `Software System`, `Container`, `Component`); `Relationship` on all relationships.

---

## Views

All views support `include`, `exclude`, `autoLayout`, and `title`.

### System Landscape
```dsl
systemLandscape [key] [description] {
    include *
    autoLayout lr
}
```

### System Context
```dsl
systemContext <softwareSystemId> [key] [description] {
    include *
    autoLayout lr
}
```

### Container
```dsl
container <softwareSystemId> [key] [description] {
    include *
    autoLayout lr
}
```

### Component
```dsl
component <containerId> [key] [description] {
    include *
    autoLayout lr
}
```

### Include / Exclude

- `include *` — all elements relevant to the view scope.
- `include user api db` — specific elements by identifier.
- `exclude legacySystem` — remove specific elements.
- `exclude "user -> legacySystem"` — remove specific relationships.

### AutoLayout

```dsl
autoLayout [tb|bt|lr|rl] [rankSeparation] [nodeSeparation]
```
Directions: `tb` (top-bottom, default), `bt`, `lr`, `rl`. Separations are integers (pixels).

---

## Identifiers

- Allowed characters: `a-zA-Z_0-9`. Convention: `camelCase`.
- Assigned with `=`: `mySystem = softwareSystem "My System"`
- Only needed when the element is referenced elsewhere.

**Flat (default):** Global namespace. All identifiers must be unique across the workspace. Simple and readable — recommended for single-system workspaces.

**Hierarchical:** `!identifiers hierarchical` at workspace level. Allows reusing names across scopes, referenced via dot notation (`system1.api -> system2.api`). Useful for multi-system workspaces where identifier collisions would occur.
