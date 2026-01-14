# Swift System Metrics

[![](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/apple/swift-system-metrics/documentation)
[![](https://img.shields.io/github/v/release/apple/swift-system-metrics)](https://github.com/apple/swift-system-metrics/releases)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-system-metrics%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/apple/swift-system-metrics)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-system-metrics%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/apple/swift-system-metrics)

A Swift library for reporting process-level system metrics (memory, CPU, file descriptors) to [Swift Metrics](https://github.com/apple/swift-metrics).

- 📚 **Documentation** is available on the [Swift Package Index](https://swiftpackageindex.com/apple/swift-system-metrics/documentation).
- 💻 **Examples** are available in the [Examples](Examples/) directory.
- 🚀 **Contributions** are welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md).
- 🪪 **License** is Apache 2.0, repeated in [LICENSE](LICENSE.txt).
- 🔒 **Security** issues should be reported via the process in [SECURITY.md](SECURITY.md).

## Overview

Swift System Metrics provides a type that periodically collects process-level system metrics and reports them to the Swift Metrics factory.

This package is designed to be run in tools and applications directly and is not expected to be used from libraries. If you'd like to report additional metrics from your library, use [Swift Metrics](https://github.com/apple/swift-metrics) directly.

## Quick start

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-system-metrics", from: "1.0.0")
```

Add the library dependency to your target:

```swift
.product(name: "SystemMetrics", package: "swift-system-metrics")
```

Import and use in your code:

```swift
import SystemMetrics
import ServiceLifecycle
import Metrics
import Logging

@main
struct Application {
  static func main() async throws {
    // Create a logger, or use one of the existing loggers
    let logger = Logger(label: "Application")
    let metrics = MyMetricsBackendImplementation()
    MetricsSystem.bootstrap(metrics)

    let service = FooService()
    // Create the monitor
    let systemMetricsMonitor = SystemMetricsMonitor(logger: logger)
    
    // Create the service
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

## Collected metrics

The monitor collects and reports the following metrics as gauges:

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

## Supported platforms and minimum versions

The library is supported on macOS and Linux.

| Component     | macOS  | Linux |
| ------------- | -----  | ------|
| SystemMetrics | ✅ 13+ | ✅ |

## Documentation

Comprehensive documentation is hosted on the [Swift Package Index](https://swiftpackageindex.com/apple/swift-system-metrics/documentation/systemmetrics).
