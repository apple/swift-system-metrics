# ``SystemMetrics``

Collect and report process-level system metrics in your application.

## Overview

Create an instance of ``SystemMetricsMonitor`` to automatically collect key process metrics and report them through the Swift Metrics API.

The monitor collects the following metrics:

- **Virtual Memory**: Total virtual memory, in bytes, that the process allocates. The monitor reports the metric as `process_virtual_memory_bytes`.
- **Resident Memory**: Physical memory, in bytes, that the process currently uses. The monitor reports the metric as `process_resident_memory_bytes`.
- **Start Time**: Process start time, in seconds, since UNIX epoch. The monitor reports the metric as `process_start_time_seconds`.
- **CPU Time**: Cumulative CPU time the process consumes, in seconds. The monitor reports the metric as `process_cpu_seconds_total`.
- **Max File Descriptors**: The maximum number of file descriptors the process can open. The monitor reports the metric as `process_max_fds`.
- **Open File Descriptors**: The number of file descriptors the process currently has open. The monitor reports the metric as `process_open_fds`.

> Note: The monitor supports these metrics only on Linux and macOS platforms.

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

## Topics

### Monitor system metrics

- <doc:GettingStarted>
- ``SystemMetricsMonitor``

### Contribute to the project

- <doc:Proposals>
