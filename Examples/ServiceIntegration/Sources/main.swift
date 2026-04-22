//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System Metrics API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift System Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift System Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncAlgorithms
import Instrumentation
import Logging
import Metrics
import OTel
import ServiceLifecycle
import SystemMetrics
import UnixSignals

struct FooService: Service {
    let logger: Logger

    func run() async throws {
        self.logger.notice("FooService starting")
        for await _ in AsyncTimerSequence(interval: .seconds(0.01), clock: .continuous)
            .cancelOnGracefulShutdown()
        {
            let j = 42
            for i in 0...1000 {
                let k = i * j
                self.logger.trace("FooService is still running", metadata: ["k": "\(k)"])
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        self.logger.notice("FooService done")
    }
}

func makeTelemetryService(
    logger: Logger,
    serviceName: String
) throws -> (service: ServiceGroup, metricsFactory: any MetricsFactory) {
    var otelConfig = OTel.Configuration.default
    otelConfig.logs.enabled = false
    otelConfig.metrics.enabled = true
    otelConfig.traces.enabled = false
    otelConfig.serviceName = serviceName
    let otelMetricsBackend = try OTel.makeMetricsBackend(configuration: otelConfig)

    // Configure SystemMetrics monitoring with an explicit metrics factory
    let systemMetricsMonitor = SystemMetricsMonitor(
        configuration: .init(pollInterval: .seconds(30)),
        metricsFactory: otelMetricsBackend.factory,
        logger: logger
    )

    // Create a named service group
    let serviceGroup = ServiceGroup(
        services: [
            otelMetricsBackend.service,
            systemMetricsMonitor,
        ],
        logger: logger,
    )
    let namedServiceConfiguration = ServiceGroupConfiguration.ServiceConfiguration(
        service: serviceGroup,
        serviceName: "Telemetry"
    )
    let serviceGroupConfiguration = ServiceGroupConfiguration(
        services: [namedServiceConfiguration],
        logger: logger
    )
    return (ServiceGroup(configuration: serviceGroupConfiguration), otelMetricsBackend.factory)
}

@main
struct Application {
    static func main() async throws {
        let applicationName = "ServiceIntegrationExample"
        let logger = Logger(label: applicationName)

        // Initialize all telemetry services
        let (telemetryService, metricsFactory) = try makeTelemetryService(
            logger: logger,
            serviceName: applicationName
        )

        // Create a service simulating some important work
        let service = FooService(logger: logger)

        let serviceGroup = ServiceGroup(
            services: [
                telemetryService,
                service,
            ],
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: logger
        )

        // Use withMetricsFactory to make the OTel factory available as a task-local
        // for any Metric objects created during the service group's run
        try await withMetricsFactory(metricsFactory) {
            try await serviceGroup.run()
        }
    }
}
