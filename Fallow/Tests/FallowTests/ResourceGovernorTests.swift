// ResourceGovernorTests.swift
// Unit tests for the ResourceGovernor policy engine.
// Part of Fallow. MIT licence.

import XCTest
@testable import FallowCore

// MARK: - Test Doubles

@MainActor
final class MockSystemMonitor: SystemMonitoring {
    var isCharging: Bool = true
    var isLowPowerMode: Bool = false
    var isSystemHealthy: Bool = true
}

@MainActor
final class MockIdleDetector: IdleDetecting {
    var isIdle: Bool = true
    var idleSeconds: TimeInterval = 600
    var idleThreshold: TimeInterval = 300
}

// MARK: - Tests

final class ResourceGovernorTests: XCTestCase {

    @MainActor
    func testAllowedWhenAllConditionsMet() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)

        let result = governor.evaluate()
        XCTAssertTrue(result.shouldContribute)
        XCTAssertEqual(result.reason, .allowed)
    }

    @MainActor
    func testBlockedWhenNotIdle() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        detector.isIdle = false
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)

        let result = governor.evaluate()
        XCTAssertFalse(result.shouldContribute)
        XCTAssertEqual(result.reason, .userNotIdle)
    }

    @MainActor
    func testBlockedOnBattery() {
        let monitor = MockSystemMonitor()
        monitor.isCharging = false
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)

        let result = governor.evaluate()
        XCTAssertFalse(result.shouldContribute)
        XCTAssertEqual(result.reason, .onBattery)
    }

    @MainActor
    func testBlockedLowPowerMode() {
        let monitor = MockSystemMonitor()
        monitor.isLowPowerMode = true
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)

        let result = governor.evaluate()
        XCTAssertFalse(result.shouldContribute)
        XCTAssertEqual(result.reason, .lowPowerMode)
    }

    @MainActor
    func testBlockedThermalPressure() {
        let monitor = MockSystemMonitor()
        monitor.isSystemHealthy = false
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)

        let result = governor.evaluate()
        XCTAssertFalse(result.shouldContribute)
        XCTAssertEqual(result.reason, .thermalPressure)
    }

    @MainActor
    func testManualPausePrecedence() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        governor.isManuallyPaused = true

        let result = governor.evaluate()
        XCTAssertFalse(result.shouldContribute)
        XCTAssertEqual(result.reason, .manuallyPaused)
    }

    @MainActor
    func testQuietHoursMidnightWrap() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        governor.settings = GovernorSettings(
            quietHoursEnabled: true,
            quietHoursStart: 23,
            quietHoursEnd: 7
        )

        let result = governor.evaluate()
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 7 {
            XCTAssertEqual(result.reason, .quietHours)
        } else {
            XCTAssertEqual(result.reason, .allowed)
        }
    }
}
