workspace "Test" "All source paths are valid." {
    model {
        sys = softwareSystem "System" {
            api = container "API" {
                properties {
                    source "src/"
                }
                orders = component "Orders" {
                    properties {
                        source "src/service.py::OrderService"
                    }
                }
                payments = component "Payments" {
                    properties {
                        source "src/service.py::PaymentProcessor"
                    }
                }
                webhook = component "Webhook" {
                    properties {
                        source "src/service.py::process_webhook"
                    }
                }
                method = component "Create Order" {
                    properties {
                        source "src/service.py::OrderService.create_order"
                    }
                }
                tsFile = component "Utils" {
                    properties {
                        source "src/utils.ts::Logger"
                    }
                }
            }
        }
    }
    views {
        systemContext sys "SC" { include * autoLayout }
    }
}
