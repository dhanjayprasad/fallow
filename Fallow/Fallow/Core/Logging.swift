// Logging.swift
// Centralised OSLog logger definitions for the Fallow app.
// Part of Fallow. MIT licence.

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.fallow.app"

    /// Logs related to KwaaiNet binary lifecycle management.
    static let kwaainet = Logger(subsystem: subsystem, category: "kwaainet")

    /// Logs related to system resource monitoring and governance.
    static let governor = Logger(subsystem: subsystem, category: "governor")

    /// Logs related to the credit ledger.
    static let credits = Logger(subsystem: subsystem, category: "credits")

    /// Logs related to the chat interface and API calls.
    static let chat = Logger(subsystem: subsystem, category: "chat")

    /// Logs related to binary and code signature verification.
    static let security = Logger(subsystem: subsystem, category: "security")

    /// Logs related to port detection and network checks.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// General app lifecycle logs.
    static let app = Logger(subsystem: subsystem, category: "app")
}
