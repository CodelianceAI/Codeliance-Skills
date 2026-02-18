workspace "Test" "File exists but AST symbol does not." {
    model {
        sys = softwareSystem "System" {
            api = container "API" {
                valid = component "Valid" {
                    properties {
                        source "src/service.py::OrderService"
                    }
                }
                badClass = component "Bad Class" {
                    properties {
                        source "src/service.py::NonExistentClass"
                    }
                }
                badMethod = component "Bad Method" {
                    properties {
                        source "src/service.py::OrderService.non_existent"
                    }
                }
            }
        }
    }
    views {
        systemContext sys "SC" { include * autoLayout }
    }
}
