// StatusMenuView.swift
// Menu bar popover showing status, controls, and quick actions.
// Part of Fallow. MIT licence.

import SwiftUI
import AppKit

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

    private func openWindowActivated(id: String) {
        openWindow(id: id)
        // LSUIElement apps do not auto-activate; bring windows to the front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Circle()
                    .fill(appState.kwaaiNetManager.status.isDaemonRunning ? .green : .secondary)
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

            if appState.systemMonitor.memoryPressure != .normal {
                Label(
                    appState.systemMonitor.memoryPressure == .critical
                        ? "Critical memory pressure"
                        : "Low memory",
                    systemImage: "memorychip"
                )
                .font(.caption)
                .foregroundStyle(appState.systemMonitor.memoryPressure == .critical ? .red : .orange)
            }

            Divider()

            // Controls
            Button {
                Task { await appState.toggleContribution() }
            } label: {
                Label(
                    appState.kwaaiNetManager.status.isDaemonRunning
                        ? "Stop Contributing" : "Start Contributing",
                    systemImage: appState.kwaaiNetManager.status.isDaemonRunning
                        ? "stop.fill" : "play.fill"
                )
            }
            .disabled(appState.kwaaiNetManager.isTransitioning)
            .buttonStyle(MenuRowButtonStyle())

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
                openWindowActivated(id: "chat")
            } label: {
                Label("Open Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(MenuRowButtonStyle())

            Button {
                openWindowActivated(id: "settings")
            } label: {
                Label("Settings...", systemImage: "gear")
            }
            .buttonStyle(MenuRowButtonStyle())

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Fallow", systemImage: "power")
            }
            .buttonStyle(MenuRowButtonStyle())
        }
        .padding(8)
        .frame(width: 280)
    }
}

/// A button style that mimics native menu row feedback: hover highlight,
/// press state, and full-width click target.
private struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(background(for: configuration))
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
    }

    private func background(for configuration: Configuration) -> Color {
        if configuration.isPressed {
            return Color.accentColor.opacity(0.25)
        } else if isHovering {
            return Color.primary.opacity(0.08)
        } else {
            return .clear
        }
    }
}
