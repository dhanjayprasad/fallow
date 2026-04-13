// ResourceGovernor.swift
// Policy engine that determines when the Mac should contribute compute.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

/// The reason the ResourceGovernor is blocking or allowing contribution.
package enum GovernorReason: String, Sendable {
    case allowed = "All conditions met"
    case userNotIdle = "Waiting for user to be idle"
    case onBattery = "Paused: running on battery"
    case lowPowerMode = "Paused: Low Power Mode is on"
    case thermalPressure = "Paused: Mac is running hot"
    case memoryPressure = "Paused: low system memory"
    case quietHours = "Paused: quiet hours active"
    case manuallyPaused = "Manually paused"
}

/// Persisted governor settings.
package struct GovernorSettings: Codable, Sendable {
    package var requireCharging: Bool = true
    package var idleThresholdMinutes: Int = 5
    package var quietHoursEnabled: Bool = false
    package var quietHoursStart: Int = 23
    package var quietHoursEnd: Int = 7
    /// If true, Fallow downloads the model automatically when chat is opened
    /// and the model isn't cached. Disable to require manual download.
    package var autoDownloadModel: Bool = true
    /// Minimum free disk space (GB) to keep after downloading the model.
    package var diskSpaceReserveGB: Int = 2

    package static let defaultSettings = GovernorSettings()

    package init(
        requireCharging: Bool = true,
        idleThresholdMinutes: Int = 5,
        quietHoursEnabled: Bool = false,
        quietHoursStart: Int = 23,
        quietHoursEnd: Int = 7,
        autoDownloadModel: Bool = true,
        diskSpaceReserveGB: Int = 2
    ) {
        self.requireCharging = requireCharging
        self.idleThresholdMinutes = idleThresholdMinutes
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.autoDownloadModel = autoDownloadModel
        self.diskSpaceReserveGB = diskSpaceReserveGB
    }
}

@MainActor
@Observable
package final class ResourceGovernor {

    let systemMonitor: any SystemMonitoring
    let idleDetector: any IdleDetecting

    package private(set) var reason: GovernorReason = .userNotIdle
    package var isManuallyPaused: Bool = false

    package var settings: GovernorSettings {
        didSet {
            persistSettings()
            idleDetector.idleThreshold = TimeInterval(settings.idleThresholdMinutes * 60)
        }
    }

    /// Whether all conditions are met for contribution.
    package var shouldContribute: Bool {
        evaluate().shouldContribute
    }

    package init(systemMonitor: any SystemMonitoring, idleDetector: any IdleDetecting) {
        self.systemMonitor = systemMonitor
        self.idleDetector = idleDetector
        self.settings = Self.loadSettings()
        self.idleDetector.idleThreshold = TimeInterval(settings.idleThresholdMinutes * 60)
    }

    /// Evaluates all gates and returns whether contribution should proceed.
    @discardableResult
    package func evaluate() -> (shouldContribute: Bool, reason: GovernorReason) {
        if isManuallyPaused {
            reason = .manuallyPaused
            return (false, reason)
        }

        if !idleDetector.isIdle {
            reason = .userNotIdle
            return (false, reason)
        }

        if settings.requireCharging && !systemMonitor.isCharging {
            reason = .onBattery
            return (false, reason)
        }

        if systemMonitor.isLowPowerMode {
            reason = .lowPowerMode
            return (false, reason)
        }

        if !systemMonitor.isSystemHealthy {
            reason = .thermalPressure
            return (false, reason)
        }

        if settings.quietHoursEnabled && isQuietHoursActive() {
            reason = .quietHours
            return (false, reason)
        }

        reason = .allowed
        return (true, .allowed)
    }

    // MARK: - Private

    private func isQuietHoursActive() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let start = settings.quietHoursStart
        let end = settings.quietHoursEnd

        if start < end {
            return hour >= start && hour < end
        } else {
            // Wraps midnight (e.g. 23:00 to 07:00)
            return hour >= start || hour < end
        }
    }

    private static let settingsKey = "governorSettings"

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private static func loadSettings() -> GovernorSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(GovernorSettings.self, from: data) else {
            return .defaultSettings
        }
        return settings
    }
}
