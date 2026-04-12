// SystemMonitor.swift
// Monitors system state: power source, thermal state, Low Power Mode.
// Part of Fallow. MIT licence.

import Foundation
import IOKit.ps
import OSLog

/// Represents the current system power state.
enum PowerSource: String, Sendable {
    case battery = "Battery"
    case charger = "AC Power"
    case unknown = "Unknown"
}

@MainActor
@Observable
final class SystemMonitor {

    private(set) var powerSource: PowerSource = .unknown
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var isLowPowerMode: Bool = false

    private var monitorTask: Task<Void, Never>?

    /// Whether the system is in a healthy thermal state for contribution.
    var isSystemHealthy: Bool {
        thermalState == .nominal || thermalState == .fair
    }

    /// Whether the Mac is plugged in to power.
    var isCharging: Bool {
        powerSource == .charger
    }

    func startMonitoring() {
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

    func stopMonitoring() {
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
            return .charger
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
