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

/// Memory pressure level reported by the kernel.
package enum MemoryPressure: String, Sendable {
    case normal
    case warning
    case critical
}

/// Protocol for system state monitoring, enabling test doubles.
@MainActor
package protocol SystemMonitoring: AnyObject {
    var isCharging: Bool { get }
    var isLowPowerMode: Bool { get }
    var isThermallyHealthy: Bool { get }
    var memoryPressure: MemoryPressure { get }
}

@MainActor
@Observable
package final class SystemMonitor: SystemMonitoring {

    package private(set) var powerSource: PowerSource = .unknown
    package private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    package private(set) var isLowPowerMode: Bool = false
    package private(set) var memoryPressure: MemoryPressure = .normal
    package private(set) var totalRAMGB: Int = 0

    private var monitorTask: Task<Void, Never>?

    /// Whether the thermal state is acceptable for contribution.
    package var isThermallyHealthy: Bool {
        thermalState == .nominal || thermalState == .fair
    }

    /// Whether the Mac is plugged in to power.
    package var isCharging: Bool {
        powerSource == .charger
    }

    package init() {
        totalRAMGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
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
        memoryPressure = currentMemoryPressure()
    }

    /// Reads kernel memory pressure level via host_statistics64.
    private func currentMemoryPressure() -> MemoryPressure {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &size)
            }
        }
        guard result == KERN_SUCCESS else { return .normal }

        // Free memory ratio: anything below 5% is critical, below 15% is warning.
        let total = Double(stats.free_count + stats.active_count + stats.inactive_count
                           + stats.wire_count + stats.compressor_page_count)
        guard total > 0 else { return .normal }
        let availableRatio = Double(stats.free_count + stats.inactive_count) / total

        if availableRatio < 0.05 { return .critical }
        if availableRatio < 0.15 { return .warning }
        return .normal
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
