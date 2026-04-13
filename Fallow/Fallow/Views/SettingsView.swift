// SettingsView.swift
// Configuration panel for ResourceGovernor and app settings.
// Part of Fallow. MIT licence.

import SwiftUI

package struct SettingsView: View {
    package var appState: AppState

    package init(appState: AppState) {
        self.appState = appState
    }

    package var body: some View {
        @Bindable var governor = appState.resourceGovernor

        Form {
            Section("Contribution") {
                Toggle(
                    "Only contribute while charging",
                    isOn: $governor.settings.requireCharging
                )

                Picker(
                    "Idle threshold",
                    selection: $governor.settings.idleThresholdMinutes
                ) {
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
            }

            Section("Chat") {
                Toggle(
                    "Auto-download model when chat opens",
                    isOn: $governor.settings.autoDownloadModel
                )

                Picker(
                    "Keep at least this much disk free",
                    selection: $governor.settings.diskSpaceReserveGB
                ) {
                    Text("1 GB").tag(1)
                    Text("2 GB").tag(2)
                    Text("5 GB").tag(5)
                    Text("10 GB").tag(10)
                }
            }

            Section("Quiet Hours") {
                Toggle(
                    "Enable quiet hours",
                    isOn: $governor.settings.quietHoursEnabled
                )

                if appState.resourceGovernor.settings.quietHoursEnabled {
                    Picker(
                        "Start",
                        selection: $governor.settings.quietHoursStart
                    ) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.formatHour(hour)).tag(hour)
                        }
                    }

                    Picker(
                        "End",
                        selection: $governor.settings.quietHoursEnd
                    ) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.formatHour(hour)).tag(hour)
                        }
                    }
                }
            }

            Section("Status") {
                LabeledContent("Daemon") {
                    Text(appState.kwaaiNetManager.status.isDaemonRunning ? "Running" : "Stopped")
                        .foregroundStyle(appState.kwaaiNetManager.status.isDaemonRunning ? .green : .secondary)
                }
                LabeledContent("Chat API") {
                    Text(appState.kwaaiNetManager.status.isApiRunning ? "Running" : "Stopped")
                        .foregroundStyle(appState.kwaaiNetManager.status.isApiRunning ? .green : .secondary)
                }

                if let model = appState.kwaaiNetManager.status.modelName {
                    LabeledContent("Model", value: model)
                }

                LabeledContent(
                    "System RAM",
                    value: "\(appState.systemMonitor.totalRAMGB) GB"
                )
                LabeledContent("Memory pressure") {
                    Text(appState.systemMonitor.memoryPressure.rawValue.capitalized)
                        .foregroundStyle(memoryPressureColour)
                }

                LabeledContent(
                    "Credits earned",
                    value: String(format: "%.0f", appState.creditLedger.creditsEarned)
                )
                LabeledContent(
                    "Credits spent",
                    value: String(format: "%.0f", appState.creditLedger.creditsSpent)
                )
                LabeledContent(
                    "Time contributed",
                    value: appState.contributionTimeFormatted
                )
            }

            Section("About") {
                LabeledContent(
                    "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                        as? String ?? "0.1.0"
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
    }

    private var memoryPressureColour: Color {
        switch appState.systemMonitor.memoryPressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):00"
        }
        return hourFormatter.string(from: date)
    }
}
