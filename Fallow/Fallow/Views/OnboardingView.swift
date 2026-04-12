// OnboardingView.swift
// First-run consent screen explaining what Fallow does.
// Part of Fallow. MIT licence.

import SwiftUI

package struct OnboardingView: View {
    @Bindable package var appState: AppState

    package init(appState: AppState) {
        self.appState = appState
    }

    package var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to Fallow")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                bulletPoint(
                    icon: "bolt.fill",
                    title: "Contribute idle compute",
                    detail: "When your Mac is idle and charging, Fallow contributes spare processing power to a distributed AI network."
                )

                bulletPoint(
                    icon: "creditcard.fill",
                    title: "Earn credits",
                    detail: "You earn Fallow credits for every minute your Mac contributes."
                )

                bulletPoint(
                    icon: "bubble.left.fill",
                    title: "Chat with AI",
                    detail: "Spend your credits chatting with LLMs through the built-in interface."
                )

                bulletPoint(
                    icon: "hand.raised.fill",
                    title: "You are in control",
                    detail: "Set when contribution happens: only while charging, only when idle, with quiet hours. Stop any time."
                )
            }

            Divider()

            Text("Fallow will only contribute when your Mac is idle and conditions you set are met. You can stop contributing at any time.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("I Understand, Get Started") {
                appState.hasCompletedOnboarding = true
                appState.onOnboardingComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 360)
    }

    private func bulletPoint(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
