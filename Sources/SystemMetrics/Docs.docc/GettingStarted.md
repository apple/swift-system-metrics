# Capturing and reporting process metrics

Use the system metrics monitor in your application to provide metrics from the process where you run your service.

### Add the project dependency

Add `swift-system-metrics` as a dependency to your app and executable target:

```bash
swift package add-dependency https://github.com/apple/swift-system-metrics --from 1.0.0
```

```bash
swift package add-target-dependency SystemMetrics MyExecutableTarget --package swift-system-metrics
```

### Create a system monitor service

Import the `SystemMetrics` module, then create and add a ``SystemMetricsMonitor`` to a service group.

```swift
import SystemMetrics
// Import and create a logger, or use one of the existing loggers
import Logging

let logger = Logger(label: "MyService")

// Create the monitor
let systemMetricsMonitor = SystemMetricsMonitor(logger: logger)
```

The monitor collects and reports metrics periodically using the global `MetricsSystem` that Swift Metrics provides.
You can configure the polling interval with your own ``SystemMetricsMonitor/Configuration``, as well as the `MetricsSystem`, when you create the monitor:

```swift
let systemMetricsMonitor = SystemMetricsMonitor(
    configuration: .init(pollInterval: .seconds(5)),
    logger: logger
)
```

### Run the service in your app

Use [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) to run the monitor as a background service with support for graceful shutdown and UNIX signal handling.
To do so, include the system metrics monitor you created in a service group and run the group in your application.

The following code bootstraps your own metrics backend, creates a system metrics monitor, and uses service lifecycle to run both: 

```swift
import SystemMetrics
import ServiceLifecycle
import Metrics
import Logging

@main
struct Application {
    static func main() async throws {
        let logger = Logger(label: "Application")
        let metrics = MyMetricsBackendImplementation()
        MetricsSystem.bootstrap(metrics)

        let service = FooService()
        let systemMetricsMonitor = SystemMetricsMonitor(logger: logger)

        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor],
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
```
