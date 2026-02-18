workspace "Test" "All source values are non-local and should be skipped." {
    model {
        sys = softwareSystem "System" {
            api = container "API" {
                url = component "URL Ref" {
                    properties {
                        source "https://github.com/org/repo/blob/main/src/file.ts"
                    }
                }
                ssh = component "SSH Ref" {
                    properties {
                        source "git@github.com:org/repo.git//src/file.ts"
                    }
                }
                fqcn = component "FQCN Ref" {
                    properties {
                        source "com.example.service.OrderService"
                    }
                }
            }
        }
    }
    views {
        systemContext sys "SC" { include * autoLayout }
    }
}
