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

// Neither detached threads nor joining guarantee immediate, deterministic
// resource clean-up on macOS.
#if canImport(Glibc) || canImport(Musl)

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import SystemMetrics
import XCTest

// Thread tests are written as XCTest to benefit from the standard serial
// execution which translates as sufficient isolation for the actions and
// verifications in the test to be consistent. The existing suites in Swift
// Testing would share process and not be serial w.r.t. each other.
final class ThreadCountTests: XCTestCase {
    func test_threadCount() throws {
        let threadCountBefore = try readMetric(\.threadCount)
        var thread = pthread_t()
        _ = pthread_create(&thread, nil, { _ in nil }, nil)
        XCTAssertEqual(try readMetric(\.threadCount), threadCountBefore + 1)
        pthread_join(thread, nil)  // Thread resources are cleaned up.
        XCTAssertEqual(try readMetric(\.threadCount), threadCountBefore)
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

#endif
