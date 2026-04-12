// SettingsView.swift
// Configuration panel for ResourceGovernor and app settings.
// Part of Fallow. MIT licence.

import SwiftUI

struct SettingsView: View {
    var appState: AppState

    var body: some View {
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
                LabeledContent("KwaaiNet") {
                    Text(
                        appState.kwaaiNetManager.status.isRunning
                            ? "Running" : "Stopped"
                    )
                    .foregroundStyle(
                        appState.kwaaiNetManager.status.isRunning
                            ? .green : .secondary
                    )
                }

                if let model = appState.kwaaiNetManager.status.modelName {
                    LabeledContent("Model", value: model)
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
