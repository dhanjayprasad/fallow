// FallowApp.swift
// Entry point for the Fallow menu bar application.
// Part of Fallow. MIT licence.

import SwiftUI
import FallowCore

@main
struct FallowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(appState: appState)
                .task { await appState.initialSetup() }
        } label: {
            Image(systemName: appState.menuBarIcon)
                .foregroundStyle(appState.menuBarColour)
        }
        .menuBarExtraStyle(.window)

        Window("Fallow Chat", id: "chat") {
            ChatView(appState: appState)
        }
        .defaultSize(width: 500, height: 600)

        Window("Fallow Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .defaultSize(width: 400, height: 500)
    }
}
