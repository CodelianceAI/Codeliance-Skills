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
            webApp = container "Web Application" "Provides the viewer and creator experience in the browser." "React SPA"

            apiGateway = container "API Gateway" "Routes and authenticates all client requests to backend services." "Node.js / Express" {
                // Components
                authMiddleware = component "Auth Middleware" "Validates JWT tokens and enforces access control." "Express Middleware"
                routeHandler = component "Route Handler" "Maps incoming requests to the appropriate backend service." "Express Router"
                rateLimiter = component "Rate Limiter" "Throttles requests to protect backend services from overload." "express-rate-limit"
            }

            videoService = container "Video Service" "Handles video upload, transcoding orchestration, and metadata management." "Java / Spring Boot" {
                uploadController = component "Upload Controller" "Accepts video uploads and initiates processing workflows." "Spring REST Controller"
                transcodingOrchestrator = component "Transcoding Orchestrator" "Manages the transcoding pipeline and tracks job progress." "Spring Service"
                videoMetadataRepository = component "Video Metadata Repository" "Reads and writes video metadata to the database." "Spring Data JPA"
                cdnClient = component "CDN Client" "Publishes transcoded video assets to the CDN for distribution." "HTTP Client"
            }

            userService = container "User Service" "Manages user accounts, profiles, subscriptions, and creator channels." "Go" {
                accountHandler = component "Account Handler" "Handles registration, login, and profile operations." "HTTP Handler"
                subscriptionManager = component "Subscription Manager" "Manages viewer subscriptions and billing lifecycle." "Service"
                channelRepository = component "Channel Repository" "Persists creator channel data and follower relationships." "pgx Repository"
                paymentClient = component "Payment Client" "Integrates with the external payment gateway for transactions." "HTTP Client"
            }

            recommendationEngine = container "Recommendation Engine" "Generates personalised video recommendations based on viewing history." "Python / FastAPI" {
                recommendationApi = component "Recommendation API" "Serves recommendation requests from the API gateway." "FastAPI Router"
                mlPipeline = component "ML Pipeline" "Runs collaborative filtering and content-based models." "scikit-learn / PyTorch"
                viewingHistoryRepository = component "Viewing History Repository" "Queries aggregated viewing data for model input." "SQLAlchemy Repository"
            }

            eventBus = container "Event Bus" "Decouples services via asynchronous event-driven messaging." "RabbitMQ" "Queue"

            videoDatabase = container "Video Database" "Stores video metadata, categories, and transcoding job state." "PostgreSQL" "Database"

            userDatabase = container "User Database" "Stores user accounts, profiles, subscriptions, and channel data." "PostgreSQL" "Database"

            analyticsDatabase = container "Analytics Database" "Stores viewing history, engagement metrics, and recommendation model data." "ClickHouse" "Database"

            // -----------------------------------------------------------
            // Container-Level Relationships
            // -----------------------------------------------------------
            webApp -> apiGateway "Makes API requests to" "HTTPS/JSON"

            apiGateway -> videoService "Forwards video requests to" "HTTPS/JSON"
            apiGateway -> userService "Forwards user requests to" "HTTPS/JSON"
            apiGateway -> recommendationEngine "Requests recommendations from" "HTTPS/JSON"

            videoService -> videoDatabase "Reads and writes video metadata" "JDBC"
            videoService -> eventBus "Publishes video lifecycle events to" "AMQP"
            videoService -> cdnProvider "Pushes transcoded video assets to" "HTTPS"

            userService -> userDatabase "Reads and writes user data" "TCP"
            userService -> paymentGateway "Processes payments via" "HTTPS/JSON"
            userService -> eventBus "Publishes subscription events to" "AMQP"

            recommendationEngine -> analyticsDatabase "Queries viewing history and metrics from" "TCP"
            recommendationEngine -> eventBus "Consumes viewing events from" "AMQP"

            eventBus -> pushNotificationService "Triggers notifications via" "HTTPS"
        }

        // ---------------------------------------------------------------
        // System-Level Relationships
        // ---------------------------------------------------------------
        viewer -> streamVault "Watches videos and manages playlists using" "HTTPS"
        contentCreator -> streamVault "Uploads videos and manages channel via" "HTTPS"
        platformAdmin -> streamVault "Administers platform settings through" "HTTPS"

        streamVault -> cdnProvider "Distributes video content via" "HTTPS"
        streamVault -> paymentGateway "Processes payments through" "HTTPS/JSON"
        streamVault -> pushNotificationService "Sends notifications via" "HTTPS"

        // ---------------------------------------------------------------
        // Component-Level Relationships — API Gateway
        // ---------------------------------------------------------------
        webApp -> authMiddleware "Sends authenticated requests to" "HTTPS/JSON"
        authMiddleware -> routeHandler "Passes validated requests to"
        routeHandler -> videoService "Routes video requests to" "HTTPS/JSON"
        routeHandler -> userService "Routes user requests to" "HTTPS/JSON"
        routeHandler -> recommendationEngine "Routes recommendation requests to" "HTTPS/JSON"
        rateLimiter -> authMiddleware "Guards incoming requests before"

        // ---------------------------------------------------------------
        // Component-Level Relationships — Video Service
        // ---------------------------------------------------------------
        apiGateway -> uploadController "Sends upload requests to" "HTTPS/JSON"
        uploadController -> transcodingOrchestrator "Initiates transcoding via"
        transcodingOrchestrator -> videoMetadataRepository "Updates job status in"
        transcodingOrchestrator -> eventBus "Publishes transcoding events to" "AMQP"
        videoMetadataRepository -> videoDatabase "Reads and writes video records" "JDBC"
        cdnClient -> cdnProvider "Pushes video assets to" "HTTPS"
        transcodingOrchestrator -> cdnClient "Sends transcoded assets to"

        // ---------------------------------------------------------------
        // Component-Level Relationships — User Service
        // ---------------------------------------------------------------
        apiGateway -> accountHandler "Sends account requests to" "HTTPS/JSON"
        accountHandler -> subscriptionManager "Delegates subscription operations to"
        subscriptionManager -> channelRepository "Reads and writes channel data via"
        subscriptionManager -> paymentClient "Initiates payment transactions via"
        channelRepository -> userDatabase "Persists channel and follower data" "TCP"
        paymentClient -> paymentGateway "Processes payments through" "HTTPS/JSON"
        subscriptionManager -> eventBus "Publishes subscription events to" "AMQP"

        // ---------------------------------------------------------------
        // Component-Level Relationships — Recommendation Engine
        // ---------------------------------------------------------------
        apiGateway -> recommendationApi "Requests recommendations from" "HTTPS/JSON"
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
