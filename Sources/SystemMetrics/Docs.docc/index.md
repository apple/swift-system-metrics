# ``SystemMetrics``

Collect and report process-level system metrics in your application.

## Overview

Swift System Metrics provides a type that periodically collects process-level system metrics and reports them to [Swift Metrics](https://github.com/apple/swift-metrics).

> Note: This package is designed to be run in tools and applications directly and is not expected to be used from libraries. If you'd like to report additional metrics from your library, use Swift Metrics directly.

### Quick start

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-system-metrics", from: "1.0.0")
```

Add the library dependency to your target:

```swift
.product(name: "SystemMetrics", package: "swift-system-metrics")
```

This example shows how to create a monitor and run it with the service group alongside your service:

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

### Collected metrics

Create an instance of ``SystemMetricsMonitor`` to automatically collect key process metrics and report them through the Swift Metrics API.

The monitor collects the following metrics:

- **Virtual Memory**: Total virtual memory, in bytes, that the process allocates.
  - Metric name: `process_virtual_memory_bytes`
- **Resident Memory**: Physical memory, in bytes, that the process currently uses.
  - Metric name: `process_resident_memory_bytes`
- **Start Time**: Process start time, in seconds, since UNIX epoch.
  - Metric name: `process_start_time_seconds`
- **CPU Time**: Cumulative CPU time the process consumes, in seconds.
  - Metric name: `process_cpu_seconds_total`
- **Max File Descriptors**: The maximum number of file descriptors the process can open.
  - Metric name: `process_max_fds`
- **Open File Descriptors**: The number of file descriptors the process currently has open.
  - Metric name: `process_open_fds`
- **Thread Count**: The number of threads in the process.
  - Metric name: `process_thread_count`

> Note: New metrics can be added in minor and patch versions.

### Rename metric labels

If your metrics backend expects different label names, use
[`MappingMetricsFactory`](https://swiftpackageindex.com/apple/swift-metrics/documentation/coremetrics/mappingmetricsfactory)
from Swift Metrics to rename labels without modifying the library. See <doc:GettingStarted> for a complete example.

### Supported platforms and minimum versions

The library is supported on macOS and Linux.

| Component     | macOS  | Linux |
| ------------- | -----  | ------|
| SystemMetrics | ✅ 13+ | ✅ |

## Topics

### Monitor system metrics

- <doc:GettingStarted>
- ``SystemMetricsMonitor``

### Contribute to the project

- <doc:Proposals>
