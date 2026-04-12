// SystemMonitor.swift
// Monitors system state: power source, thermal state, Low Power Mode.
// Part of Fallow. MIT licence.

import Foundation
import IOKit.ps
import OSLog

/// Represents the current system power state.
package enum PowerSource: String, Sendable {
    case battery = "Battery"
    case charger = "AC Power"
    case unknown = "Unknown"
}

/// Protocol for system state monitoring, enabling test doubles.
@MainActor
package protocol SystemMonitoring: AnyObject {
    var isCharging: Bool { get }
    var isLowPowerMode: Bool { get }
    var isSystemHealthy: Bool { get }
}

@MainActor
@Observable
package final class SystemMonitor: SystemMonitoring {

    package private(set) var powerSource: PowerSource = .unknown
    package private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    package private(set) var isLowPowerMode: Bool = false

    private var monitorTask: Task<Void, Never>?

    /// Whether the system is in a healthy thermal state for contribution.
    package var isSystemHealthy: Bool {
        thermalState == .nominal || thermalState == .fair
    }

    /// Whether the Mac is plugged in to power.
    package var isCharging: Bool {
        powerSource == .charger
    }

    package func startMonitoring() {
        stopMonitoring()
        refresh()

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }

        Logger.governor.info("System monitoring started")
    }

    package func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - Private

    private func refresh() {
        thermalState = ProcessInfo.processInfo.thermalState
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        powerSource = currentPowerSource()
    }

    private func currentPowerSource() -> PowerSource {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            // IOKit query failed; cannot determine power state
            return .unknown
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // Desktop Mac with no battery; treat as always on charger
            return .charger
        }

        guard let powerType = IOPSGetProvidingPowerSourceType(snapshot)?
            .takeUnretainedValue() as String? else {
            return .unknown
        }

        if powerType == kIOPSACPowerValue as String {
            return .charger
        } else if powerType == kIOPSBatteryPowerValue as String {
            return .battery
        }

        return .unknown
    }
}
