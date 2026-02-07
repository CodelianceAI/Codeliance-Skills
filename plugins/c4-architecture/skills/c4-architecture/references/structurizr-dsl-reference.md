# Structurizr DSL Quick Reference

Based on the [Structurizr DSL language reference](https://docs.structurizr.com/dsl/language). Structurizr DSL is open source under the Apache-2.0 licence.

---

## Workspace

```dsl
workspace [name] [description] {
    !identifiers hierarchical
    model { }
    views { }
}
```

- `name` and `description` are optional (quote strings with spaces).
- `!identifiers hierarchical` enables scoped identifiers with dot notation (recommended).

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

**Implied relationships:** A relationship between lower-level elements (e.g., `user -> api`) automatically implies a relationship between their parents (e.g., `user -> system`). System context views work without explicit system-level relationships. Disable with `!impliedRelationships false`.

**Relationship identifiers:** `rel = user -> system "Uses" "HTTPS"`

---

## Tags

Tags classify elements for filtering. They are additive -- they never replace default tags.

**Inline** -- the last positional string on an element definition:
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

**Auto-applied defaults:** `Element` on all elements; type-specific tag (`Person`, `Software System`, `Container`, `Component`, `Deployment Node`, `Infrastructure Node`); `Relationship` on all relationships.

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

### Deployment
```dsl
deployment <*|softwareSystemId> <environmentName> [key] [description] {
    include *
    autoLayout lr
}
```
Use `*` to include all systems. `environmentName` must match a `deploymentEnvironment` name.

### Dynamic
```dsl
dynamic <*|softwareSystemId|containerId> [key] [description] {
    title "User Login Flow"
    user -> webapp "Submits credentials"
    webapp -> authService "Validates credentials"
    authService -> db "Queries user record"
    autoLayout lr
}
```
Each line is an ordered step. Order is implicit from line position.

### Filtered
```dsl
filtered <baseViewKey> <include|exclude> <tags> [key] [description]
```
Example:
```dsl
filtered "landscape" include "External,Relationship" "externalOnly"
filtered "landscape" exclude "External" "internalOnly"
```

### Include / Exclude

- `include *` -- all elements relevant to the view scope.
- `include user api db` -- specific elements by identifier.
- `exclude legacySystem` -- remove specific elements.
- `exclude "user -> legacySystem"` -- remove specific relationships.

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

**Flat (default):** Global namespace. Duplicate names cause errors.

**Hierarchical:** `!identifiers hierarchical` at workspace level. Reference with dot notation:
```dsl
workspace {
    !identifiers hierarchical
    model {
        s1 = softwareSystem "System 1" {
            api = container "API"
        }
        s2 = softwareSystem "System 2" {
            api = container "API"
        }
        s1.api -> s2.api "Calls"
    }
}
```

---

## Properties and URLs

```dsl
mySystem = softwareSystem "System" {
    properties {
        owner "Team Alpha"
        repo "github.com/org/repo"
    }
    url "https://github.com/org/repo"
}
```

---

## Deployment

### Deployment Environment and Nodes

```dsl
model {
    system = softwareSystem "System" {
        api = container "API" "" "Go"
        db = container "Database" "" "PostgreSQL" "Database"
    }

    prod = deploymentEnvironment "Production" {
        deploymentNode "AWS" "" "Amazon Web Services" {
            deploymentNode "ECS" "" "AWS ECS" {
                containerInstance api
            }
            deploymentNode "RDS" "" "AWS RDS" {
                containerInstance db
            }
        }
    }
}
```

### Deployment Node

```dsl
deploymentNode "Name" [description] [technology] [tags] [instances] {
    deploymentNode "Child" { }
    containerInstance <containerIdentifier>
    softwareSystemInstance <systemIdentifier>
    infrastructureNode "Name" [description] [technology] [tags]
}
```
- `instances`: a number (`"4"`) or range (`"1..N"`). Default `"1"`.
- Default tags: `Element`, `Deployment Node`.

### Infrastructure Node

For non-container infrastructure (load balancers, DNS, firewalls).

```dsl
lb = infrastructureNode "Load Balancer" "Routes traffic" "AWS ALB"
```
Default tags: `Element`, `Infrastructure Node`.

### Container Instance

```dsl
containerInstance <containerIdentifier> [deploymentGroups] [tags]
```
Inherits tags from the referenced container. Adds `Container Instance` tag.

### Deployment View

```dsl
views {
    deployment system "Production" "prodView" {
        include *
        autoLayout lr
    }
}
```
