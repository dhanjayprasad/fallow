// StatusMenuView.swift
// Menu bar popover showing status, controls, and quick actions.
// Part of Fallow. MIT licence.

import SwiftUI

package struct StatusMenuView: View {
    @Bindable package var appState: AppState
    @Environment(\.openWindow) private var openWindow

    package init(appState: AppState) {
        self.appState = appState
    }

    package var body: some View {
        if !appState.hasCompletedOnboarding {
            OnboardingView(appState: appState)
        } else {
            statusContent
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Circle()
                    .fill(appState.kwaaiNetManager.status.isRunning ? .green : .secondary)
                    .frame(width: 10, height: 10)
                Text(appState.statusText)
                    .font(.headline)
                Spacer()
            }

            // Setup progress indicator
            if case .running(let message) = appState.kwaaiNetManager.setupState {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if case .failed(let reason) = appState.kwaaiNetManager.setupState {
                Text("Setup failed: \(reason)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let error = appState.kwaaiNetManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            // Controls
            Button {
                Task { await appState.toggleContribution() }
            } label: {
                Label(
                    appState.kwaaiNetManager.status.isRunning
                        ? "Stop Contributing" : "Start Contributing",
                    systemImage: appState.kwaaiNetManager.status.isRunning
                        ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(appState.kwaaiNetManager.isTransitioning)
            .buttonStyle(.plain)

            Toggle("Auto-contribute when idle", isOn: $appState.autoContribute)
                .toggleStyle(.switch)
                .controlSize(.small)

            Divider()

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "Balance: \(String(format: "%.0f", appState.creditLedger.balance)) credits",
                    systemImage: "creditcard"
                )
                Label(
                    "Time contributed: \(appState.contributionTimeFormatted)",
                    systemImage: "clock"
                )

                if appState.resourceGovernor.reason != .allowed {
                    Label(appState.resourceGovernor.reason.rawValue, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .font(.callout)

            Divider()

            // Actions
            Button {
                openWindow(id: "chat")
            } label: {
                Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings...", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit Fallow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 280)
    }
}
