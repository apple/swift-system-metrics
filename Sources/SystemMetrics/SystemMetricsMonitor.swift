//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import AsyncAlgorithms
public import CoreMetrics
import Foundation
public import Logging
public import ServiceLifecycle

/// A monitor that periodically collects and reports system metrics.
///
/// `SystemMetricsMonitor` automatically collects process-level system metrics
/// (such as memory usage and CPU time) and reports them through the Swift Metrics API.
///
/// Example usage:
/// ```swift
/// import SystemMetrics
/// import Logging
///
/// let logger = Logger(label: "MyService")
/// let monitor = SystemMetricsMonitor(logger: logger)
/// let serviceGroup = ServiceGroup(
///     services: [monitor],
///     gracefulShutdownSignals: [.sigint],
///     cancellationSignals: [.sigterm],
///     logger: logger
/// )
/// try await serviceGroup.run()
/// ```
public struct SystemMetricsMonitor: Service {
    /// Configuration for the system metrics monitor.
    let configuration: SystemMetricsMonitor.Configuration

    /// Optional metrics factory for testing. If nil, uses `MetricsSystem.factory`.
    let metricsFactory: (any MetricsFactory)?

    /// The provider responsible for collecting system metrics data.
    let dataProvider: any SystemMetricsProvider

    /// Internal logger
    let logger: Logger

    /// Pre-initialized gauges for metrics reporting
    let virtualMemoryBytesGauge: Gauge
    let residentMemoryBytesGauge: Gauge
    let startTimeSecondsGauge: Gauge
    let cpuSecondsTotalGauge: Gauge
    let maxFileDescriptorsGauge: Gauge
    let openFileDescriptorsGauge: Gauge

    /// Create a new monitor for system metrics.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - metricsFactory: The metrics factory to use for creating metrics. If `nil`, the monitor initializes with the global metrics factory.
    ///   - dataProvider: The provider to use for collecting system metrics data.
    ///   - logger: A custom logger.
    package init(
        configuration: SystemMetricsMonitor.Configuration,
        metricsFactory: (any MetricsFactory)?,
        dataProvider: any SystemMetricsProvider,
        logger: Logger
    ) {
        self.configuration = configuration
        self.metricsFactory = metricsFactory
        self.dataProvider = dataProvider
        self.logger = logger

        // Initialize gauges once to avoid repeated creation in updateMetrics()
        let effectiveMetricsFactory = metricsFactory ?? MetricsSystem.factory
        self.virtualMemoryBytesGauge = Gauge(
            label: configuration.labels.label(for: \.virtualMemoryBytes),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
        self.residentMemoryBytesGauge = Gauge(
            label: configuration.labels.label(for: \.residentMemoryBytes),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
        self.startTimeSecondsGauge = Gauge(
            label: configuration.labels.label(for: \.startTimeSeconds),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
        self.cpuSecondsTotalGauge = Gauge(
            label: configuration.labels.label(for: \.cpuSecondsTotal),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
        self.maxFileDescriptorsGauge = Gauge(
            label: configuration.labels.label(for: \.maxFileDescriptors),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
        self.openFileDescriptorsGauge = Gauge(
            label: configuration.labels.label(for: \.openFileDescriptors),
            dimensions: configuration.dimensions,
            factory: effectiveMetricsFactory
        )
    }

    /// Create a new monitor for system metrics with a custom data provider that you provide.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - dataProvider: The provider to use for collecting system metrics data.
    ///   - logger: A custom logger.
    package init(
        configuration: SystemMetricsMonitor.Configuration,
        dataProvider: any SystemMetricsProvider,
        logger: Logger
    ) {
        self.init(
            configuration: configuration,
            metricsFactory: nil,
            dataProvider: dataProvider,
            logger: logger
        )
    }

    /// Create a new monitor for system metrics that send metrics to backend using the metrics factory that you provide.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - metricsFactory: The [metrics factory](https://swiftpackageindex.com/apple/swift-metrics/documentation/coremetrics/metricsfactory) to use for creating metrics.
    ///   - logger: A custom logger.
    public init(
        configuration: SystemMetricsMonitor.Configuration = .default,
        metricsFactory: any MetricsFactory,
        logger: Logger
    ) {
        self.init(
            configuration: configuration,
            metricsFactory: metricsFactory,
            dataProvider: SystemMetricsMonitorDataProvider(configuration: configuration),
            logger: logger
        )
    }

    /// Create a new monitor for system metrics using the global metrics factory.
    ///
    /// If you can't, or don't want to use the process global metrics that the Metrics API provides,
    /// consider using ``init(configuration:metricsFactory:logger:)`` instead.
    /// For example, if you have different backends for different metrics,
    /// use a [metrics factory](https://swiftpackageindex.com/apple/swift-metrics/documentation/coremetrics/metricsfactory)
    /// from the backend where you want to send system metrics.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - logger: A custom logger.
    public init(
        configuration: SystemMetricsMonitor.Configuration = .default,
        logger: Logger
    ) {
        self.init(
            configuration: configuration,
            metricsFactory: nil,
            dataProvider: SystemMetricsMonitorDataProvider(configuration: configuration),
            logger: logger
        )
    }

    /// Collect and report system metrics once.
    ///
    /// This method collects current system metrics and reports them as gauges
    /// using the configured labels and dimensions. If metric collection fails
    /// or the current platform doesn't support it, this method returns without
    /// reporting any metrics.
    package func updateMetrics() async {
        guard let metrics = await self.dataProvider.data() else {
            self.logger.debug("Failed to fetch the latest system metrics")
            return
        }
        self.logger.trace(
            "Fetched the latest system metrics",
            metadata: [
                self.configuration.labels.virtualMemoryBytes.description: Logger.MetadataValue(
                    "\(metrics.virtualMemoryBytes)"
                ),
                self.configuration.labels.residentMemoryBytes.description: Logger.MetadataValue(
                    "\(metrics.residentMemoryBytes)"
                ),
                self.configuration.labels.startTimeSeconds.description: Logger.MetadataValue(
                    "\(metrics.startTimeSeconds)"
                ),
                self.configuration.labels.cpuSecondsTotal.description: Logger.MetadataValue("\(metrics.cpuSeconds)"),
                self.configuration.labels.maxFileDescriptors.description: Logger.MetadataValue(
                    "\(metrics.maxFileDescriptors)"
                ),
                self.configuration.labels.openFileDescriptors.description: Logger.MetadataValue(
                    "\(metrics.openFileDescriptors)"
                ),
            ]
        )
        self.virtualMemoryBytesGauge.record(metrics.virtualMemoryBytes)
        self.residentMemoryBytesGauge.record(metrics.residentMemoryBytes)
        self.startTimeSecondsGauge.record(metrics.startTimeSeconds)
        self.cpuSecondsTotalGauge.record(metrics.cpuSeconds)
        self.maxFileDescriptorsGauge.record(metrics.maxFileDescriptors)
        self.openFileDescriptorsGauge.record(metrics.openFileDescriptors)
    }

    /// Start the monitoring loop, collecting and reporting metrics at the configured interval.
    ///
    /// This method runs indefinitely, periodically collecting and reporting system metrics
    /// according to the poll interval specified in the configuration. It will only return
    /// if the async task is cancelled.
    public func run() async throws {
        for await _ in AsyncTimerSequence(interval: self.configuration.interval, clock: .continuous)
            .cancelOnGracefulShutdown()
        {
            await self.updateMetrics()
        }
    }
}

/// Provides system metrics data.
///
/// Types that conform to this protocol provide system metrics data
/// to a ``SystemMetricsMonitor``. This allows for flexible data collection
/// strategies, including custom implementations for testing.
package protocol SystemMetricsProvider: Sendable {
    /// Retrieve current system metrics data.
    ///
    /// - Returns: Current system metrics, or `nil` if collection failed
    ///            or the current platform doesn't support it.
    func data() async -> SystemMetricsMonitor.Data?
}

/// Default implementation of system metrics provider that collects system metrics data.
///
/// This provider collects process-level metrics from the operating system.
/// Use this provider as the default when you don't specify a custom provider.
package struct SystemMetricsMonitorDataProvider: Sendable {
    let configuration: SystemMetricsMonitor.Configuration

    package init(configuration: SystemMetricsMonitor.Configuration) {
        self.configuration = configuration
    }
}

extension SystemMetricsMonitor {
    /// System metrics data.
    ///
    /// The current list of metrics exposed is a superset of the
    /// [Prometheus Client Library Guidelines](https://prometheus.io/docs/instrumenting/writing_clientlibs/#standard-and-runtime-collectors).
    package struct Data: Sendable {
        /// Virtual memory size in bytes.
        package var virtualMemoryBytes: Int
        /// Resident memory size in bytes.
        package var residentMemoryBytes: Int
        /// Start time of the process since UNIX epoch in seconds.
        package var startTimeSeconds: Int
        /// Total user and system CPU time spent in seconds.
        package var cpuSeconds: Double
        /// Maximum number of open file descriptors.
        package var maxFileDescriptors: Int
        /// Number of open file descriptors.
        package var openFileDescriptors: Int

        /// Create a new instance of metrics data.
        ///
        /// - Parameters:
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Process start time since UNIX epoch in seconds.
        ///     - cpuSeconds: Total user and system CPU time spent in seconds.
        ///     - maxFileDescriptors: Maximum number of open file descriptors.
        ///     - openFileDescriptors: Number of open file descriptors.
        package init(
            virtualMemoryBytes: Int,
            residentMemoryBytes: Int,
            startTimeSeconds: Int,
            cpuSeconds: Double,
            maxFileDescriptors: Int,
            openFileDescriptors: Int
        ) {
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSeconds = cpuSeconds
            self.maxFileDescriptors = maxFileDescriptors
            self.openFileDescriptors = openFileDescriptors
        }
    }
}
