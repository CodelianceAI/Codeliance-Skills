// The example workspace plus a deployment view, so the viewer tests have nested boxes to collapse.
workspace extends ../../../skills/c4-architecture/examples/example-workspace.dsl {

    model {
        live = deploymentEnvironment "Live" {
            deploymentNode "Cloud region" "" "Hosted cloud" {
                deploymentNode "Kubernetes cluster" "" "Kubernetes" {
                    deploymentNode "Frontend pool" "" "Node pool" {
                        containerInstance webApp
                        containerInstance apiGateway
                    }
                    deploymentNode "Services pool" "" "Node pool" {
                        containerInstance videoService
                        containerInstance userService
                        containerInstance recommendationEngine
                    }
                    deploymentNode "Messaging" "" "StatefulSet" {
                        containerInstance eventBus
                    }
                }
                deploymentNode "Managed databases" "" "Managed PostgreSQL and ClickHouse" {
                    containerInstance videoDatabase
                    containerInstance userDatabase
                    containerInstance analyticsDatabase
                }
            }
        }
    }

    views {
        deployment streamVault live "LiveDeployment" {
            include *
            autoLayout
        }
    }
}
