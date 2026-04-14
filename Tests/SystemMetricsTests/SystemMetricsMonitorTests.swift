//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift System Metrics API open source project
//
// Copyright (c) 2018-2020 Apple Inc. and the Swift System Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift System Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CoreMetrics
import Dispatch
import Foundation
import Logging
import MetricsTestKit
import SystemMetrics
import Testing

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

struct MockMetricsProvider: SystemMetricsProvider {
    let mockData: SystemMetricsMonitor.Data?

    func data() async -> SystemMetricsMonitor.Data? {
        mockData
    }
}

@Suite("SystemMetricsMonitor Tests")
struct SystemMetricsMonitorTests {
    @Test("Custom labels with prefix are correctly formatted")
    func systemMetricsLabels() throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "pfx+",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        #expect(labels.label(for: \.virtualMemoryBytes) == "pfx+vmb")
        #expect(labels.label(for: \.residentMemoryBytes) == "pfx+rmb")
        #expect(labels.label(for: \.startTimeSeconds) == "pfx+sts")
        #expect(labels.label(for: \.cpuSecondsTotal) == "pfx+cpt")
        #expect(labels.label(for: \.maxFileDescriptors) == "pfx+mfd")
        #expect(labels.label(for: \.openFileDescriptors) == "pfx+ofd")
        #expect(labels.label(for: \.threadCount) == "pfx+tc")
    }

    @Test("Configuration preserves all provided settings")
    func systemMetricsConfiguration() throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "pfx_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )
        let dimensions = [("app", "example"), ("environment", "production")]
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .microseconds(123_456_789),
            labels: labels,
            dimensions: dimensions
        )

        #expect(configuration.interval == .microseconds(123_456_789))

        #expect(configuration.labels.label(for: \.virtualMemoryBytes) == "pfx_vmb")
        #expect(configuration.labels.label(for: \.residentMemoryBytes) == "pfx_rmb")
        #expect(configuration.labels.label(for: \.startTimeSeconds) == "pfx_sts")
        #expect(configuration.labels.label(for: \.cpuSecondsTotal) == "pfx_cpt")
        #expect(configuration.labels.label(for: \.maxFileDescriptors) == "pfx_mfd")
        #expect(configuration.labels.label(for: \.openFileDescriptors) == "pfx_ofd")
        #expect(configuration.labels.label(for: \.threadCount) == "pfx_tc")

        #expect(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        #expect(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        #expect(!configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        #expect(!configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }

    @Test("Monitor with custom provider reports metrics correctly")
    func monitorWithCustomProvider() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            threadCount: 7000
        )

        let provider = MockMetricsProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider,
            logger: logger
        )

        await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)

        let rmbGauge = try testMetrics.expectGauge("test_rmb")
        #expect(rmbGauge.lastValue == 2000)

        let stsGauge = try testMetrics.expectGauge("test_sts")
        #expect(stsGauge.lastValue == 3000)

        let cptGauge = try testMetrics.expectGauge("test_cpt")
        #expect(cptGauge.lastValue == 4000)

        let mfdGauge = try testMetrics.expectGauge("test_mfd")
        #expect(mfdGauge.lastValue == 5000)

        let ofdGauge = try testMetrics.expectGauge("test_ofd")
        #expect(ofdGauge.lastValue == 6000)

        let tcGauge = try testMetrics.expectGauge("test_tc")
        #expect(tcGauge.lastValue == 7000)
    }

    @Test("Monitor with nil provider does not report metrics")
    func monitorWithNilProvider() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")
        let provider = MockMetricsProvider(mockData: nil)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider,
            logger: logger
        )

        // Recorders are created along with the Monitor
        #expect(testMetrics.recorders.count == 7)

        await monitor.updateMetrics()

        // But no values recorded
        for recorder in testMetrics.recorders {
            #expect(recorder.values.isEmpty)
        }
    }

    @Test("Monitor with dimensions includes them in recorded metrics")
    func monitorWithDimensions() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            threadCount: 7000
        )

        let provider = MockMetricsProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let dimensions = [("service", "myapp"), ("environment", "production")]
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels,
            dimensions: dimensions
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider,
            logger: logger
        )

        await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("test_vmb", dimensions)
        #expect(vmbGauge.lastValue == 1000)
    }

    @Test("Monitor run() method collects metrics periodically")
    func monitorRunPeriodically() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")

        actor CallCountingProvider: SystemMetricsProvider {
            var callCount = 0
            let mockData: SystemMetricsMonitor.Data

            init(mockData: SystemMetricsMonitor.Data) {
                self.mockData = mockData
            }

            func data() async -> SystemMetricsMonitor.Data? {
                callCount += 1
                return mockData
            }

            func getCallCount() -> Int {
                callCount
            }
        }

        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            threadCount: 7000
        )

        let provider = CallCountingProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .milliseconds(100),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider,
            logger: logger
        )

        // Wait for the monitor to run a few times
        #expect(
            try await wait(
                noLongerThan: .seconds(15.0),
                for: {
                    await provider.getCallCount() >= 3
                },
                while: {
                    try await monitor.run()
                }
            )
        )

        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)
    }

    @Test("Monitor with default provider uses platform implementation")
    func monitorWithDefaultProvider() async throws {
        let logger = Logger(label: "test")
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom provider - uses SystemMetricsMonitorDataProvider internally
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            logger: logger
        )

        await monitor.updateMetrics()
        let vmbGauge = try testMetrics.expectGauge("test_vmb")

        #if os(macOS) || os(Linux)
        let lastValue = try #require(vmbGauge.lastValue)
        #expect(lastValue > 0)
        #endif
    }

    @Test("MappingMetricsFactory renames all default labels")
    func monitorWithMappingFactory() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            threadCount: 7000
        )

        let provider = MockMetricsProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        // Rename every label using a dictionary. This pins the exact
        // default label names the library uses, so the test fails if
        // any label is accidentally changed.
        let labelMapping: [String: String] = [
            "process_virtual_memory_bytes": "app_vm_bytes",
            "process_resident_memory_bytes": "app_rm_bytes",
            "process_start_time_seconds": "app_start_time",
            "process_cpu_seconds_total": "app_cpu_total",
            "process_max_fds": "app_max_fds",
            "process_open_fds": "app_open_fds",
            "process_thread_count": "app_threads",
        ]

        let mappingFactory = testMetrics.withLabelAndDimensionsMapping { label, dimensions in
            guard let mapped = labelMapping[label] else {
                preconditionFailure("Unexpected metric label: \(label)")
            }
            return (mapped, dimensions)
        }

        let monitor = SystemMetricsMonitor(
            configuration: .init(pollInterval: .seconds(1)),
            metricsFactory: mappingFactory,
            dataProvider: provider,
            logger: logger
        )

        await monitor.updateMetrics()

        let vmGauge = try testMetrics.expectGauge("app_vm_bytes")
        #expect(vmGauge.lastValue == 1000)

        let rmbGauge = try testMetrics.expectGauge("app_rm_bytes")
        #expect(rmbGauge.lastValue == 2000)

        let stsGauge = try testMetrics.expectGauge("app_start_time")
        #expect(stsGauge.lastValue == 3000)

        let cpuGauge = try testMetrics.expectGauge("app_cpu_total")
        #expect(cpuGauge.lastValue == 4000)

        let mfdGauge = try testMetrics.expectGauge("app_max_fds")
        #expect(mfdGauge.lastValue == 5000)

        let ofdGauge = try testMetrics.expectGauge("app_open_fds")
        #expect(ofdGauge.lastValue == 6000)

        let tcGauge = try testMetrics.expectGauge("app_threads")
        #expect(tcGauge.lastValue == 7000)

        // Verify that exactly 7 gauges were created — no more, no fewer.
        #expect(testMetrics.recorders.count == 7)
    }
}

@Suite("SystemMetrics with MetricsSystem Initialization Tests", .serialized)
struct SystemMetricsInitializationTests {
    static let sharedSetup: TestMetrics = {
        let testMetrics = TestMetrics()
        MetricsSystem.bootstrap(testMetrics)
        return testMetrics
    }()

    let testMetrics: TestMetrics = Self.sharedSetup

    @Test("Monitor uses global MetricsSystem when no factory provided")
    func monitorUsesGlobalMetricsSystem() async throws {
        let logger = Logger(label: "SystemMetricsMonitorTests")
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            threadCount: 7000
        )

        let provider = MockMetricsProvider(mockData: mockData)

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "global_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom factory provided - should use global MetricsSystem
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            dataProvider: provider,
            logger: logger
        )

        await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("global_vmb")
        #expect(vmbGauge.lastValue == 1000)

        let rmbGauge = try testMetrics.expectGauge("global_rmb")
        #expect(rmbGauge.lastValue == 2000)
    }

    @Test("Monitor with default provider uses platform implementation")
    func monitorWithDefaultProvider() async throws {
        let logger = Logger(label: "test")
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "default_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd",
            threadCount: "tc"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom provider - uses SystemMetricsMonitorDataProvider internally
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            logger: logger
        )

        await monitor.updateMetrics()
        let vmbGauge = try testMetrics.expectGauge("default_vmb")

        #if os(macOS) || os(Linux)
        let lastValue = try #require(vmbGauge.lastValue)
        #expect(lastValue > 0)
        #endif
    }
}
