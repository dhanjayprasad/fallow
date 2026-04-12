// ResourceGovernorTests.swift
// Unit tests for the ResourceGovernor policy engine.
// Part of Fallow. MIT licence.

import Testing
import Foundation
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

@Suite("ResourceGovernor")
struct ResourceGovernorTests {

    @MainActor @Test("Allows contribution when all conditions met")
    func allowedWhenAllConditionsMet() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        let result = governor.evaluate()
        #expect(result.shouldContribute == true)
        #expect(result.reason == .allowed)
    }

    @MainActor @Test("Blocks when user is not idle")
    func blockedWhenNotIdle() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        detector.isIdle = false
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        let result = governor.evaluate()
        #expect(result.shouldContribute == false)
        #expect(result.reason == .userNotIdle)
    }

    @MainActor @Test("Blocks when on battery with requireCharging enabled")
    func blockedOnBattery() {
        let monitor = MockSystemMonitor()
        monitor.isCharging = false
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        let result = governor.evaluate()
        #expect(result.shouldContribute == false)
        #expect(result.reason == .onBattery)
    }

    @MainActor @Test("Blocks when Low Power Mode is on")
    func blockedLowPowerMode() {
        let monitor = MockSystemMonitor()
        monitor.isLowPowerMode = true
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        let result = governor.evaluate()
        #expect(result.shouldContribute == false)
        #expect(result.reason == .lowPowerMode)
    }

    @MainActor @Test("Blocks when thermal pressure is high")
    func blockedThermalPressure() {
        let monitor = MockSystemMonitor()
        monitor.isSystemHealthy = false
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        let result = governor.evaluate()
        #expect(result.shouldContribute == false)
        #expect(result.reason == .thermalPressure)
    }

    @MainActor @Test("Manual pause takes precedence over all conditions")
    func manualPausePrecedence() {
        let monitor = MockSystemMonitor()
        let detector = MockIdleDetector()
        let governor = ResourceGovernor(systemMonitor: monitor, idleDetector: detector)
        governor.isManuallyPaused = true
        let result = governor.evaluate()
        #expect(result.shouldContribute == false)
        #expect(result.reason == .manuallyPaused)
    }

    @MainActor @Test("Quiet hours wrapping midnight (23:00 to 07:00)")
    func quietHoursMidnightWrap() {
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
            #expect(result.reason == .quietHours)
        } else {
            #expect(result.reason == .allowed)
        }
    }
}
