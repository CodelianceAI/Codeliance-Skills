workspace "Test" "Contains a source path to a file that does not exist." {
    model {
        sys = softwareSystem "System" {
            api = container "API" {
                valid = component "Valid" {
                    properties {
                        source "src/service.py"
                    }
                }
                missing = component "Missing" {
                    properties {
                        source "src/does-not-exist.py"
                    }
                }
            }
        }
    }
    views {
        systemContext sys "SC" { include * autoLayout }
    }
}
