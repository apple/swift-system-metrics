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

import Foundation
import SystemMetrics
import XCTest

// Thread tests are written as XCTest to benefit from its default process
// isolation, as the number of threads in parallel execution of tests in shared
// process is succeptible to thread count changes unrelated to the conditions
// exercised in these tests.
final class ThreadCountTests: XCTestCase {
    func test_threadCount() throws {
        let threadCountBefore = try readMetric(\.threadCount)

        #if os(macOS)
        // On macOS, even after oining on a terminated or detached thread the
        // resources have not yet been reaped deterministically by the OS, thus
        // testing the only the increase in the gauge.
        Thread.detachNewThread {}
        XCTAssertEqual(try readMetric(\.threadCount), threadCountBefore + 1)

        #elseif canImport(Glibc) || canImport(Musl)
        // In Linux, with recent kernels, after joining on the thread
        // thread resources are consistently found already released, so both
        // the increase and decrease of the gauge are tested.
        var thread = pthread_t()
        _ = pthread_create(&thread, nil, { _ in nil }, nil)
        XCTAssertEqual(try readMetric(\.threadCount), threadCountBefore + 1)
        pthread_join(thread, nil)
        XCTAssertEqual(try readMetric(\.threadCount), threadCountBefore)
        #endif
    }

    private func readMetric<Result>(
        _ keyPath: KeyPath<SystemMetricsMonitor.Data, Result>
    ) throws -> Result {
        let metrics = try readMetrics()
        return metrics[keyPath: keyPath]
    }

    private func readMetrics() throws -> SystemMetricsMonitor.Data {
        #if os(macOS)
        try XCTUnwrap(SystemMetricsMonitorDataProvider.darwinSystemMetrics())
        #elseif os(Linux)
        try XCTUnwrap(SystemMetricsMonitorDataProvider.linuxSystemMetrics())
        #endif
    }
}
