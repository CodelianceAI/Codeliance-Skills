# Structurizr DSL Advanced Reference

Extended syntax for deployment, dynamic views, filtered views, and metadata. See `structurizr-dsl-reference.md` for core elements.

Based on the [Structurizr DSL language reference](https://docs.structurizr.com/dsl/language). Structurizr DSL is open source under the Apache-2.0 licence.

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

---

## Dynamic Views

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

---

## Filtered Views

```dsl
filtered <baseViewKey> <include|exclude> <tags> [key] [description]
```
Example:
```dsl
filtered "landscape" include "External,Relationship" "externalOnly"
filtered "landscape" exclude "External" "internalOnly"
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
