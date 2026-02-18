workspace "StreamVault" "A video streaming platform for content delivery, creator tools, and viewer engagement." {

    model {

        // ---------------------------------------------------------------
        // People
        // ---------------------------------------------------------------
        viewer = person "Viewer" "Watches videos, manages playlists, and subscribes to channels."
        contentCreator = person "Content Creator" "Uploads videos, manages channel, and reviews analytics."
        platformAdmin = person "Platform Admin" "Manages platform settings, moderates content, and monitors system health."

        // ---------------------------------------------------------------
        // External Systems
        // ---------------------------------------------------------------
        cdnProvider = softwareSystem "CDN Provider" "Distributes video content to viewers globally via edge caches." "External"
        paymentGateway = softwareSystem "Payment Gateway" "Processes subscription payments and creator payouts." "External"
        pushNotificationService = softwareSystem "Push Notification Service" "Delivers push notifications to mobile and web clients." "External"

        // ---------------------------------------------------------------
        // Primary Software System
        // ---------------------------------------------------------------
        streamVault = softwareSystem "StreamVault Platform" "Enables viewers to stream video content and creators to publish and monetise their channels." {

            // -----------------------------------------------------------
            // Containers
            // -----------------------------------------------------------
            webApp = container "Web Application" "Provides the viewer and creator experience in the browser." "React SPA" {
                properties {
                    source "web/"
                }
            }

            apiGateway = container "API Gateway" "Routes and authenticates all client requests to backend services." "Node.js / Express" {
                properties {
                    source "services/api-gateway/"
                }

                // Components
                authMiddleware = component "Auth Middleware" "Validates JWT tokens and enforces access control." "Express Middleware" {
                    properties {
                        source "services/api-gateway/src/middleware/auth.ts"
                    }
                }
                routeHandler = component "Route Handler" "Maps incoming requests to the appropriate backend service." "Express Router" {
                    properties {
                        source "services/api-gateway/src/routes/"
                    }
                }
                rateLimiter = component "Rate Limiter" "Throttles requests to protect backend services from overload." "express-rate-limit" {
                    properties {
                        source "services/api-gateway/src/middleware/rate-limiter.ts"
                    }
                }
            }

            videoService = container "Video Service" "Handles video upload, transcoding orchestration, and metadata management." "Java / Spring Boot" {
                properties {
                    source "services/video/"
                }

                uploadController = component "Upload Controller" "Accepts video uploads and initiates processing workflows." "Spring REST Controller" {
                    properties {
                        source "services/video/src/main/java/com/streamvault/video/controller/UploadController.java::UploadController"
                    }
                }
                transcodingOrchestrator = component "Transcoding Orchestrator" "Manages the transcoding pipeline and tracks job progress." "Spring Service" {
                    properties {
                        source "services/video/src/main/java/com/streamvault/video/service/TranscodingOrchestrator.java::TranscodingOrchestrator"
                    }
                }
                videoMetadataRepository = component "Video Metadata Repository" "Reads and writes video metadata to the database." "Spring Data JPA" {
                    properties {
                        source "services/video/src/main/java/com/streamvault/video/repository/VideoMetadataRepository.java"
                    }
                }
                cdnClient = component "CDN Client" "Publishes transcoded video assets to the CDN for distribution." "HTTP Client" {
                    properties {
                        source "services/video/src/main/java/com/streamvault/video/client/CdnClient.java"
                    }
                }
            }

            userService = container "User Service" "Manages user accounts, profiles, subscriptions, and creator channels." "Go" {
                properties {
                    source "services/user/"
                }

                accountHandler = component "Account Handler" "Handles registration, login, and profile operations." "HTTP Handler" {
                    properties {
                        source "services/user/handler/account.go"
                    }
                }
                subscriptionManager = component "Subscription Manager" "Manages viewer subscriptions and billing lifecycle." "Service" {
                    properties {
                        source "services/user/service/subscription.go"
                    }
                }
                channelRepository = component "Channel Repository" "Persists creator channel data and follower relationships." "pgx Repository" {
                    properties {
                        source "services/user/repository/channel.go"
                    }
                }
                paymentClient = component "Payment Client" "Integrates with the external payment gateway for transactions." "HTTP Client" {
                    properties {
                        source "services/user/client/payment.go"
                    }
                }
            }

            recommendationEngine = container "Recommendation Engine" "Generates personalised video recommendations based on viewing history." "Python / FastAPI" {
                properties {
                    source "services/recommendation/"
                }

                recommendationApi = component "Recommendation API" "Serves recommendation requests from the API gateway." "FastAPI Router" {
                    properties {
                        source "services/recommendation/app/api/recommendations.py"
                    }
                }
                mlPipeline = component "ML Pipeline" "Runs collaborative filtering and content-based models." "scikit-learn / PyTorch" {
                    properties {
                        source "services/recommendation/app/ml/"
                    }
                }
                viewingHistoryRepository = component "Viewing History Repository" "Queries aggregated viewing data for model input." "SQLAlchemy Repository" {
                    properties {
                        source "services/recommendation/app/repository/viewing_history.py"
                    }
                }
            }

            eventBus = container "Event Bus" "Decouples services via asynchronous event-driven messaging." "RabbitMQ" "Queue"

            videoDatabase = container "Video Database" "Stores video metadata, categories, and transcoding job state." "PostgreSQL" "Database"

            userDatabase = container "User Database" "Stores user accounts, profiles, subscriptions, and channel data." "PostgreSQL" "Database"

            analyticsDatabase = container "Analytics Database" "Stores viewing history, engagement metrics, and recommendation model data." "ClickHouse" "Database"

            // -----------------------------------------------------------
            // Container-Level Relationships
            // Only relationships with no component-level equivalent.
            // All other container-level relationships are implied from
            // component-level definitions below.
            // -----------------------------------------------------------
            recommendationEngine -> eventBus "Consumes viewing events from" "AMQP"
            eventBus -> pushNotificationService "Triggers notifications via" "HTTPS"
        }

        // ---------------------------------------------------------------
        // Person → Container Relationships
        // People reach containers through the Web Application (intermediary),
        // so person→component relationships are not needed — the container
        // view already shows who accesses what.
        // ---------------------------------------------------------------
        viewer -> webApp "Watches videos and manages playlists using" "HTTPS"
        contentCreator -> webApp "Uploads videos and manages channel via" "HTTPS"
        platformAdmin -> webApp "Administers platform settings through" "HTTPS"

        // viewer -> streamVault, contentCreator -> streamVault, etc.
        // are implied by person → webApp (webApp is inside streamVault).

        // ---------------------------------------------------------------
        // Component-Level Relationships — API Gateway
        // ---------------------------------------------------------------
        webApp -> authMiddleware "Sends authenticated requests to" "HTTPS/JSON"
        authMiddleware -> routeHandler "Passes validated requests to"
        rateLimiter -> authMiddleware "Guards incoming requests before"

        // Cross-container: component → component (implies apiGateway → container)
        routeHandler -> uploadController "Routes video requests to" "HTTPS/JSON"
        routeHandler -> accountHandler "Routes user requests to" "HTTPS/JSON"
        routeHandler -> recommendationApi "Routes recommendation requests to" "HTTPS/JSON"

        // ---------------------------------------------------------------
        // Component-Level Relationships — Video Service
        // ---------------------------------------------------------------
        uploadController -> transcodingOrchestrator "Initiates transcoding via"
        transcodingOrchestrator -> videoMetadataRepository "Updates job status in"
        transcodingOrchestrator -> eventBus "Publishes transcoding events to" "AMQP"
        videoMetadataRepository -> videoDatabase "Reads and writes video records" "JDBC"
        cdnClient -> cdnProvider "Pushes video assets to" "HTTPS"
        transcodingOrchestrator -> cdnClient "Sends transcoded assets to"

        // ---------------------------------------------------------------
        // Component-Level Relationships — User Service
        // ---------------------------------------------------------------
        accountHandler -> subscriptionManager "Delegates subscription operations to"
        subscriptionManager -> channelRepository "Reads and writes channel data via"
        subscriptionManager -> paymentClient "Initiates payment transactions via"
        channelRepository -> userDatabase "Persists channel and follower data" "TCP"
        paymentClient -> paymentGateway "Processes payments through" "HTTPS/JSON"
        subscriptionManager -> eventBus "Publishes subscription events to" "AMQP"

        // ---------------------------------------------------------------
        // Component-Level Relationships — Recommendation Engine
        // ---------------------------------------------------------------
        recommendationApi -> mlPipeline "Invokes recommendation models in"
        mlPipeline -> viewingHistoryRepository "Reads aggregated viewing data from"
        viewingHistoryRepository -> analyticsDatabase "Queries viewing history" "TCP"
    }

    views {

        // System Context View
        systemContext streamVault "SystemContext" {
            include *
            autoLayout
        }

        // Container View
        container streamVault "Containers" {
            include *
            autoLayout
        }

        // Component View — API Gateway
        component apiGateway "ComponentsOfApiGateway" {
            include *
            autoLayout
        }

        // Component View — Video Service
        component videoService "ComponentsOfVideoService" {
            include *
            autoLayout
        }

        // Component View — User Service
        component userService "ComponentsOfUserService" {
            include *
            autoLayout
        }

        // Component View — Recommendation Engine
        component recommendationEngine "ComponentsOfRecommendationEngine" {
            include *
            autoLayout
        }
    }
}
